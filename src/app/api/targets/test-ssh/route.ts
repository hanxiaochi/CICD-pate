export const runtime = "nodejs";

import { NextRequest, NextResponse } from 'next/server';
import { connectSSH } from '@/lib/ssh';

function requireAuth(request: NextRequest) {
  const auth = request.headers.get('authorization');
  if (!auth || !auth.startsWith('Bearer ') || !auth.slice(7).trim()) {
    throw new Error('Unauthorized');
  }
}

interface SSHTestTarget {
  host: string;
  ssh_user?: string;
  ssh_port?: number;
  auth_type: 'password' | 'key';
  password?: string;
  private_key?: string;
  passphrase?: string;
}

interface SSHTestOptions {
  timeoutMs?: number;
  retries?: number;
  concurrency?: number;
}

interface BatchSSHRequest {
  targets: SSHTestTarget[];
  timeoutMs?: number;
  retries?: number;
  concurrency?: number;
}

async function testSingleSSH(
  target: SSHTestTarget, 
  options: SSHTestOptions = {}
): Promise<{ ok: boolean; latencyMs?: number; error?: string; host: string }> {
  const startTime = Date.now();
  const { timeoutMs = 6000, retries = 0 } = options;
  
  let lastError = '';
  
  for (let attempt = 0; attempt <= retries; attempt++) {
    try {
      const sshConfig: any = {
        host: target.host,
        port: target.ssh_port || 22,
        username: target.ssh_user || 'root',
        timeout: timeoutMs
      };

      if (target.auth_type === 'password') {
        sshConfig.password = target.password || '';
      } else if (target.auth_type === 'key') {
        if (!target.private_key) {
          return {
            ok: false,
            error: 'Private key is required for key-based authentication',
            host: target.host
          };
        }
        sshConfig.privateKey = target.private_key;
        if (target.passphrase) {
          sshConfig.passphrase = target.passphrase;
        }
      }

      const client = await connectSSH(sshConfig);
      client.end();
      
      const latencyMs = Date.now() - startTime;
      return {
        ok: true,
        latencyMs,
        host: target.host
      };
    } catch (error) {
      lastError = error instanceof Error ? error.message : String(error);
      
      // Don't retry on authentication errors
      if (lastError.toLowerCase().includes('auth')) {
        break;
      }
    }
  }

  return {
    ok: false,
    error: lastError,
    host: target.host
  };
}

async function runBatchWithConcurrency<T, R>(
  items: T[],
  processor: (item: T) => Promise<R>,
  concurrency: number = 5
): Promise<R[]> {
  const results: R[] = [];
  
  for (let i = 0; i < items.length; i += concurrency) {
    const batch = items.slice(i, i + concurrency);
    const batchPromises = batch.map(processor);
    const batchResults = await Promise.all(batchPromises);
    results.push(...batchResults);
  }
  
  return results;
}

export async function POST(request: NextRequest) {
  try {
    requireAuth(request);

    const contentType = request.headers.get('content-type') || '';
    let requestData: any = {};

    // Handle both JSON and FormData
    if (contentType.includes('application/json')) {
      requestData = await request.json();
    } else if (contentType.includes('multipart/form-data')) {
      const formData = await request.formData();
      
      // Extract single target fields from FormData (existing format)
      requestData.host = formData.get('host')?.toString() || '';
      requestData.ssh_user = formData.get('ssh_user')?.toString() || 'root';
      requestData.ssh_port = formData.get('ssh_port')?.toString() || '22';
      requestData.auth_type = formData.get('auth_type')?.toString() || '';
      requestData.password = formData.get('password')?.toString() || '';
      requestData.passphrase = formData.get('passphrase')?.toString() || '';
      
      // Handle private_key from text field or file upload
      const privateKeyField = formData.get('private_key');
      if (privateKeyField instanceof File) {
        try {
          requestData.private_key = await privateKeyField.text();
        } catch (error) {
          return NextResponse.json({
            error: "Failed to read uploaded private key file",
            code: "FILE_READ_ERROR"
          }, { status: 400 });
        }
      } else {
        requestData.private_key = privateKeyField?.toString() || '';
      }
    } else {
      return NextResponse.json({
        error: "Content-Type must be application/json or multipart/form-data",
        code: "INVALID_CONTENT_TYPE"
      }, { status: 400 });
    }

    // Check if this is a batch request
    if (requestData.targets && Array.isArray(requestData.targets)) {
      // Batch SSH test
      const batchRequest: BatchSSHRequest = requestData;
      const { 
        targets, 
        timeoutMs = 6000, 
        retries = 0, 
        concurrency = 5 
      } = batchRequest;

      if (!targets.length) {
        return NextResponse.json({
          error: "At least one target is required for batch testing",
          code: "NO_TARGETS"
        }, { status: 400 });
      }

      // Validate each target
      for (let i = 0; i < targets.length; i++) {
        const target = targets[i];
        
        if (!target.host || target.host.trim() === '') {
          return NextResponse.json({
            error: `Target ${i + 1}: Host is required`,
            code: "MISSING_HOST"
          }, { status: 400 });
        }

        if (!target.auth_type || (target.auth_type !== 'password' && target.auth_type !== 'key')) {
          return NextResponse.json({
            error: `Target ${i + 1}: auth_type must be 'password' or 'key'`,
            code: "INVALID_AUTH_TYPE"
          }, { status: 400 });
        }

        if (target.auth_type === 'key' && (!target.private_key || target.private_key.trim() === '')) {
          return NextResponse.json({
            error: `Target ${i + 1}: private_key is required when auth_type is 'key'`,
            code: "MISSING_PRIVATE_KEY"
          }, { status: 400 });
        }
      }

      // Run batch test with concurrency control
      const testOptions = { timeoutMs, retries };
      const results = await runBatchWithConcurrency(
        targets,
        (target) => testSingleSSH(target, testOptions),
        Math.min(Math.max(concurrency, 1), 10) // Limit concurrency between 1-10
      );

      return NextResponse.json({
        results,
        summary: {
          total: results.length,
          success: results.filter(r => r.ok).length,
          failed: results.filter(r => !r.ok).length
        }
      }, { status: 200 });

    } else {
      // Single SSH test (existing functionality)
      const {
        host,
        ssh_user = 'root',
        ssh_port = '22',
        auth_type,
        password,
        private_key,
        passphrase,
        timeout
      } = requestData;

      // Validate required fields
      if (!host || host.trim() === '') {
        return NextResponse.json({
          error: "Host is required and cannot be empty",
          code: "MISSING_HOST"
        }, { status: 400 });
      }

      if (!auth_type || (auth_type !== 'password' && auth_type !== 'key')) {
        return NextResponse.json({
          error: "auth_type must be 'password' or 'key'",
          code: "INVALID_AUTH_TYPE"
        }, { status: 400 });
      }

      // Validate SSH port
      const portNumber = parseInt(ssh_port.toString());
      if (isNaN(portNumber) || portNumber < 1 || portNumber > 65535) {
        return NextResponse.json({
          error: "ssh_port must be an integer between 1 and 65535",
          code: "INVALID_PORT"
        }, { status: 400 });
      }

      // Validate auth-specific requirements
      if (auth_type === 'key') {
        if (!private_key || private_key.trim() === '') {
          return NextResponse.json({
            error: "private_key is required when auth_type is 'key'",
            code: "MISSING_PRIVATE_KEY"
          }, { status: 400 });
        }
      }

      const target: SSHTestTarget = {
        host: host.trim(),
        ssh_user: ssh_user || 'root',
        ssh_port: portNumber,
        auth_type,
        password,
        private_key,
        passphrase
      };

      const timeoutMs = Math.min(Math.max(Number(timeout || 6000), 1000), 30000);
      const result = await testSingleSSH(target, { timeoutMs });

      return NextResponse.json(result, { status: 200 });
    }

  } catch (error) {
    console.error('SSH test error:', error);
    
    if (error instanceof Error && error.message === 'Unauthorized') {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }
    
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
  }
}
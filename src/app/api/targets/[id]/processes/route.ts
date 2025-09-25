import { NextRequest, NextResponse } from 'next/server';
import { db } from '@/db';
import { targets } from '@/db/schema';
import { eq } from 'drizzle-orm';
import { getCurrentUser, requireRole, handleRoleError } from '@/lib/auth';
import { logSuccess, logFailure, AUDIT_ACTIONS } from '@/lib/audit';
import { decryptSecret } from '@/lib/crypto';
import { connectSSH, listProcesses } from '@/lib/ssh';

export async function GET(
  request: NextRequest,
  { params }: { params: { id: string } }
) {
  let user = null;
  try {
    user = await getCurrentUser(request);
    requireRole(user, 'read');

    const { id } = params;
    const { searchParams } = new URL(request.url);
    const filter = searchParams.get('filter'); // Optional process filter

    if (!id || isNaN(parseInt(id))) {
      return NextResponse.json({ 
        error: "Valid ID is required"
      }, { status: 400 });
    }

    // Get target from database
    const targetResult = await db.select()
      .from(targets)
      .where(eq(targets.id, parseInt(id)))
      .limit(1);

    if (targetResult.length === 0) {
      await logFailure(request, user.id, AUDIT_ACTIONS.TARGETS_PROCESSES, 'targets', parseInt(id), {
        error: 'Target not found',
        filter
      });

      return NextResponse.json({ error: 'Target not found' }, { status: 404 });
    }

    const target = targetResult[0];

    // Prepare SSH connection config
    const sshConfig: any = {
      host: target.host,
      port: target.sshPort,
      username: target.sshUser,
      timeout: 10000 // 10 second timeout
    };

    // Decrypt and set credentials based on auth type
    try {
      if (target.authType === 'password') {
        if (!target.password) {
          return NextResponse.json({ 
            error: 'No password configured for this target' 
          }, { status: 400 });
        }
        sshConfig.password = decryptSecret(target.password);
      } else if (target.authType === 'key') {
        if (!target.privateKey) {
          return NextResponse.json({ 
            error: 'No private key configured for this target' 
          }, { status: 400 });
        }
        sshConfig.privateKey = decryptSecret(target.privateKey);
        
        if (target.passphrase) {
          sshConfig.passphrase = decryptSecret(target.passphrase);
        }
      }
    } catch (decryptError) {
      await logFailure(request, user.id, AUDIT_ACTIONS.TARGETS_PROCESSES, 'targets', parseInt(id), {
        error: 'Failed to decrypt credentials',
        filter
      });

      return NextResponse.json({ 
        error: 'Failed to decrypt target credentials' 
      }, { status: 500 });
    }

    // Connect via SSH and list processes
    let client;
    try {
      client = await connectSSH(sshConfig);
      const processes = await listProcesses(client, filter || undefined);
      
      client.end();

      await logSuccess(request, user.id, AUDIT_ACTIONS.TARGETS_PROCESSES, 'targets', parseInt(id), {
        filter,
        processCount: processes.length
      });

      return NextResponse.json(processes);

    } catch (sshError) {
      if (client) {
        client.end();
      }

      await logFailure(request, user.id, AUDIT_ACTIONS.TARGETS_PROCESSES, 'targets', parseInt(id), {
        error: `SSH operation failed: ${sshError}`,
        filter
      });

      return NextResponse.json({ 
        error: `SSH operation failed: ${sshError instanceof Error ? sshError.message : String(sshError)}` 
      }, { status: 500 });
    }

  } catch (error) {
    console.error('GET /api/targets/[id]/processes error:', error);
    
    const roleError = handleRoleError(error);
    
    await logFailure(request, user?.id || null, AUDIT_ACTIONS.TARGETS_PROCESSES, 'targets', 
      params.id ? parseInt(params.id) : null, {
        error: roleError.error,
        filter: new URL(request.url).searchParams.get('filter')
      });

    return NextResponse.json(roleError, { status: roleError.status });
  }
}
export const runtime = "nodejs";

import { NextRequest, NextResponse } from 'next/server';
import { db } from '@/db';
import { targets } from '@/db/schema';
import { eq } from 'drizzle-orm';
import { decryptCredential } from '@/lib/encryption';
import { connectSSH } from '@/lib/ssh';

function requireAuth(request: NextRequest) {
  const auth = request.headers.get('authorization');
  if (!auth || !auth.startsWith('Bearer ') || !auth.slice(7).trim()) {
    throw new Error('Unauthorized');
  }
}

export async function POST(request: NextRequest) {
  try {
    requireAuth(request);

    const body = await request.json();
    const { id, timeoutMs = 6000 } = body;

    // Validate target ID
    if (!id || typeof id !== 'number') {
      return NextResponse.json({
        error: "Valid target ID is required",
        code: "INVALID_ID"
      }, { status: 400 });
    }

    // Get target from database
    const targetResult = await db.select()
      .from(targets)
      .where(eq(targets.id, id))
      .limit(1);

    if (targetResult.length === 0) {
      return NextResponse.json({
        error: "Target not found",
        code: "TARGET_NOT_FOUND"
      }, { status: 404 });
    }

    const target = targetResult[0];

    // Check if target has stored credentials
    if (target.authType === 'password' && !target.hasPassword) {
      return NextResponse.json({
        error: "No password stored for this target",
        code: "NO_CREDENTIALS"
      }, { status: 400 });
    }

    if (target.authType === 'key' && !target.hasPrivateKey) {
      return NextResponse.json({
        error: "No private key stored for this target",
        code: "NO_CREDENTIALS"
      }, { status: 400 });
    }

    // Prepare SSH connection config
    const sshConfig: any = {
      host: target.host,
      port: target.sshPort,
      username: target.sshUser,
      timeout: Math.min(Math.max(timeoutMs, 1000), 30000)
    };

    try {
      // Decrypt and set credentials based on auth type
      if (target.authType === 'password' && target.passwordEncrypted) {
        sshConfig.password = decryptCredential(target.passwordEncrypted);
      } else if (target.authType === 'key' && target.privateKeyEncrypted) {
        sshConfig.privateKey = decryptCredential(target.privateKeyEncrypted);
        
        if (target.passphraseEncrypted) {
          sshConfig.passphrase = decryptCredential(target.passphraseEncrypted);
        }
      }
    } catch (decryptError) {
      return NextResponse.json({
        error: "Failed to decrypt stored credentials",
        code: "DECRYPT_ERROR"
      }, { status: 500 });
    }

    // Test SSH connection with latency measurement
    const startTime = Date.now();
    
    try {
      const client = await connectSSH(sshConfig);
      client.end();
      
      const latencyMs = Date.now() - startTime;
      
      return NextResponse.json({
        ok: true,
        latencyMs
      });
      
    } catch (sshError) {
      return NextResponse.json({
        ok: false,
        error: sshError instanceof Error ? sshError.message : 'SSH connection failed'
      }, { status: 200 }); // Return 200 for failed connection attempts
    }

  } catch (error) {
    console.error('Test connection error:', error);
    
    if (error instanceof Error && error.message === 'Unauthorized') {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }
    
    return NextResponse.json({
      error: 'Internal server error',
      code: 'INTERNAL_ERROR'
    }, { status: 500 });
  }
}
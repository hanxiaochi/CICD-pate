export const runtime = "nodejs";

import { NextRequest, NextResponse } from 'next/server';
import { db } from '@/db';
import { targets } from '@/db/schema';
import { eq } from 'drizzle-orm';
import { decryptCredential } from '@/lib/encryption';
import { connectSSH, listFiles } from '@/lib/ssh';

function requireAuth(request: NextRequest) {
  const auth = request.headers.get('authorization');
  if (!auth || !auth.startsWith('Bearer ') || !auth.slice(7).trim()) {
    throw new Error('Unauthorized');
  }
}

export async function GET(
  request: NextRequest,
  { params }: { params: { id: string } }
) {
  try {
    requireAuth(request);

    const { id } = params;
    const { searchParams } = new URL(request.url);
    const path = searchParams.get('path');

    if (!id || isNaN(parseInt(id))) {
      return NextResponse.json({ 
        error: "Valid ID is required"
      }, { status: 400 });
    }

    if (!path) {
      return NextResponse.json({ 
        error: "Path parameter is required"
      }, { status: 400 });
    }

    // Get target from database
    const targetResult = await db.select()
      .from(targets)
      .where(eq(targets.id, parseInt(id)))
      .limit(1);

    if (targetResult.length === 0) {
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
        if (!target.hasPassword || !target.passwordEncrypted) {
          return NextResponse.json({ 
            error: 'No password configured for this target' 
          }, { status: 400 });
        }
        sshConfig.password = decryptCredential(target.passwordEncrypted);
      } else if (target.authType === 'key') {
        if (!target.hasPrivateKey || !target.privateKeyEncrypted) {
          return NextResponse.json({ 
            error: 'No private key configured for this target' 
          }, { status: 400 });
        }
        sshConfig.privateKey = decryptCredential(target.privateKeyEncrypted);
        
        if (target.passphraseEncrypted) {
          sshConfig.passphrase = decryptCredential(target.passphraseEncrypted);
        }
      }
    } catch (decryptError) {
      return NextResponse.json({ 
        error: 'Failed to decrypt target credentials' 
      }, { status: 500 });
    }

    // Connect via SSH and list files
    let client;
    try {
      client = await connectSSH(sshConfig);
      const entries = await listFiles(client, path);
      
      client.end();

      return NextResponse.json({
        path,
        entries
      });

    } catch (sshError) {
      if (client) {
        client.end();
      }

      return NextResponse.json({ 
        error: `SSH operation failed: ${sshError instanceof Error ? sshError.message : String(sshError)}` 
      }, { status: 500 });
    }

  } catch (error) {
    console.error('GET /api/targets/[id]/fs error:', error);
    
    if (error instanceof Error && error.message === 'Unauthorized') {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }
    
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
  }
}
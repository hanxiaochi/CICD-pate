export const runtime = "nodejs";
import { NextRequest, NextResponse } from 'next/server';
import { db } from '@/db';
import { targets } from '@/db/schema';
import { eq } from 'drizzle-orm';
import { encryptCredential } from '@/lib/encryption';

function requireAuth(request: NextRequest) {
  const auth = request.headers.get('authorization');
  if (!auth || !auth.startsWith('Bearer ') || !auth.slice(7).trim()) {
    throw new Error('Unauthorized');
  }
}

function validatePort(port: number): boolean {
  return Number.isInteger(port) && port >= 1 && port <= 65535;
}

function maskTarget(target: any) {
  return {
    id: target.id,
    name: target.name,
    host: target.host,
    sshUser: target.sshUser,
    sshPort: target.sshPort,
    rootPath: target.rootPath,
    env: target.env,
    authType: target.authType,
    hasPassword: target.hasPassword,
    hasPrivateKey: target.hasPrivateKey,
    createdAt: target.createdAt,
    updatedAt: target.updatedAt
  };
}

export async function GET(
  request: NextRequest,
  { params }: { params: { id: string } }
) {
  try {
    requireAuth(request);

    const { id } = params;

    if (!id || isNaN(parseInt(id))) {
      return NextResponse.json({ 
        error: "Valid ID is required"
      }, { status: 400 });
    }

    const target = await db.select()
      .from(targets)
      .where(eq(targets.id, parseInt(id)))
      .limit(1);

    if (target.length === 0) {
      return NextResponse.json({ error: 'Target not found' }, { status: 404 });
    }

    const maskedTarget = maskTarget(target[0]);

    return NextResponse.json(maskedTarget);
  } catch (error) {
    console.error('GET /api/targets/[id] error:', error);
    
    if (error instanceof Error && error.message === 'Unauthorized') {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }
    
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
  }
}

export async function PUT(
  request: NextRequest,
  { params }: { params: { id: string } }
) {
  try {
    requireAuth(request);

    const { id } = params;

    if (!id || isNaN(parseInt(id))) {
      return NextResponse.json({ 
        error: "Valid ID is required"
      }, { status: 400 });
    }

    const body = await request.json();
    const {
      name,
      host,
      ssh_user,
      ssh_port,
      root_path,
      auth_type,
      password,
      private_key,
      passphrase,
      env
    } = body;

    // Check if target exists
    const existingTarget = await db.select()
      .from(targets)
      .where(eq(targets.id, parseInt(id)))
      .limit(1);

    if (existingTarget.length === 0) {
      return NextResponse.json({ error: 'Target not found' }, { status: 404 });
    }

    // Build update object
    const updateData: any = {
      updatedAt: Date.now()
    };

    // Update basic fields
    if (name !== undefined) {
      if (!name || typeof name !== 'string' || !name.trim()) {
        return NextResponse.json({
          error: 'Name must be a non-empty string'
        }, { status: 400 });
      }
      updateData.name = name.trim();
    }
    if (host !== undefined) {
      if (!host || typeof host !== 'string' || !host.trim()) {
        return NextResponse.json({
          error: 'Host must be a non-empty string'
        }, { status: 400 });
      }
      updateData.host = host.trim();
    }
    if (ssh_user !== undefined) {
      updateData.sshUser = ssh_user?.trim() || 'root';
    }
    if (ssh_port !== undefined) {
      if (!validatePort(ssh_port)) {
        return NextResponse.json({
          error: 'SSH port must be an integer between 1 and 65535'
        }, { status: 400 });
      }
      updateData.sshPort = ssh_port;
    }
    if (root_path !== undefined) {
      updateData.rootPath = root_path?.trim() || '/opt/apps';
    }
    if (env !== undefined) {
      updateData.env = env?.trim() || 'prod';
    }

    // Handle auth type and credentials
    const finalAuthType = auth_type || existingTarget[0].authType;
    if (auth_type !== undefined) {
      if (auth_type !== 'password' && auth_type !== 'key') {
        return NextResponse.json({
          error: 'Auth type must be either "password" or "key"'
        }, { status: 400 });
      }
      updateData.authType = auth_type;
    }

    // Handle credential updates based on auth type
    if (finalAuthType === 'password') {
      // Clear key-based credentials when switching to password
      if (auth_type === 'password') {
        updateData.privateKeyEncrypted = null;
        updateData.passphraseEncrypted = null;
        updateData.hasPrivateKey = false;
      }
      
      if (password !== undefined) {
        if (password === '' || password === null) {
          updateData.passwordEncrypted = null;
          updateData.hasPassword = false;
        } else {
          updateData.passwordEncrypted = encryptCredential(password);
          updateData.hasPassword = true;
        }
      }
    } else if (finalAuthType === 'key') {
      // Clear password when switching to key
      if (auth_type === 'key') {
        updateData.passwordEncrypted = null;
        updateData.hasPassword = false;
      }
      
      if (private_key !== undefined) {
        if (private_key === '' || private_key === null) {
          updateData.privateKeyEncrypted = null;
          updateData.hasPrivateKey = false;
        } else {
          updateData.privateKeyEncrypted = encryptCredential(private_key.trim());
          updateData.hasPrivateKey = true;
        }
      }
      
      if (passphrase !== undefined) {
        if (passphrase === '' || passphrase === null) {
          updateData.passphraseEncrypted = null;
        } else {
          updateData.passphraseEncrypted = encryptCredential(passphrase);
        }
      }
    }

    const updatedTarget = await db.update(targets)
      .set(updateData)
      .where(eq(targets.id, parseInt(id)))
      .returning();

    const maskedTarget = maskTarget(updatedTarget[0]);

    return NextResponse.json(maskedTarget);

  } catch (error) {
    console.error('PUT /api/targets/[id] error:', error);
    
    if (error instanceof Error && error.message === 'Unauthorized') {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }
    
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
  }
}

export async function DELETE(
  request: NextRequest,
  { params }: { params: { id: string } }
) {
  try {
    requireAuth(request);

    const { id } = params;

    if (!id || isNaN(parseInt(id))) {
      return NextResponse.json({ 
        error: "Valid ID is required"
      }, { status: 400 });
    }

    // Check if target exists
    const existingTarget = await db.select()
      .from(targets)
      .where(eq(targets.id, parseInt(id)))
      .limit(1);

    if (existingTarget.length === 0) {
      return NextResponse.json({ error: 'Target not found' }, { status: 404 });
    }

    const deletedTarget = await db.delete(targets)
      .where(eq(targets.id, parseInt(id)))
      .returning();

    const maskedTarget = maskTarget(deletedTarget[0]);

    return NextResponse.json({
      message: 'Target deleted successfully',
      deletedTarget: maskedTarget
    });
  } catch (error) {
    console.error('DELETE /api/targets/[id] error:', error);
    
    if (error instanceof Error && error.message === 'Unauthorized') {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }
    
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
  }
}
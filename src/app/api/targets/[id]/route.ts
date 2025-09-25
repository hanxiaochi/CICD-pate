import { NextRequest, NextResponse } from 'next/server';
import { db } from '@/db';
import { targets } from '@/db/schema';
import { eq } from 'drizzle-orm';
import { getCurrentUser, requireRole, handleRoleError } from '@/lib/auth';
import { logSuccess, logFailure, AUDIT_ACTIONS } from '@/lib/audit';
import { encryptSecret, decryptSecret, isEncrypted } from '@/lib/crypto';

const VALID_AUTH_TYPES = ['password', 'key'] as const;
type AuthType = typeof VALID_AUTH_TYPES[number];

function validatePort(port: number): boolean {
  return Number.isInteger(port) && port >= 1 && port <= 65535;
}

function maskTarget(target: any) {
  return {
    ...target,
    password: null, // Never expose plaintext passwords
    privateKey: null, // Never expose plaintext private keys  
    passphrase: null, // Never expose plaintext passphrases
    hasPassword: target.authType === 'password' && !!target.password,
    hasPrivateKey: target.authType === 'key' && !!target.privateKey,
  };
}

export async function GET(
  request: NextRequest,
  { params }: { params: { id: string } }
) {
  let user = null;
  try {
    user = await getCurrentUser(request);
    requireRole(user, 'read');

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
      await logFailure(request, user.id, AUDIT_ACTIONS.TARGETS_LIST, 'targets', parseInt(id), {
        error: 'Target not found'
      });

      return NextResponse.json({ error: 'Target not found' }, { status: 404 });
    }

    const maskedTarget = maskTarget(target[0]);

    await logSuccess(request, user.id, AUDIT_ACTIONS.TARGETS_LIST, 'targets', parseInt(id));

    return NextResponse.json(maskedTarget);
  } catch (error) {
    const roleError = handleRoleError(error);
    
    await logFailure(request, user?.id || null, AUDIT_ACTIONS.TARGETS_LIST, 'targets', 
      params.id ? parseInt(params.id) : null, {
        error: roleError.error
      });

    return NextResponse.json(roleError, { status: roleError.status });
  }
}

export async function PUT(
  request: NextRequest,
  { params }: { params: { id: string } }
) {
  let user = null;
  try {
    user = await getCurrentUser(request);
    requireRole(user, 'write');

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
      await logFailure(request, user.id, AUDIT_ACTIONS.TARGETS_UPDATE, 'targets', parseInt(id), {
        error: 'Target not found'
      });

      return NextResponse.json({ error: 'Target not found' }, { status: 404 });
    }

    // Validate required fields if provided
    if (name !== undefined) {
      if (!name || typeof name !== 'string' || !name.trim()) {
        return NextResponse.json({
          error: 'Name must be a non-empty string'
        }, { status: 400 });
      }
    }

    if (host !== undefined) {
      if (!host || typeof host !== 'string' || !host.trim()) {
        return NextResponse.json({
          error: 'Host must be a non-empty string'
        }, { status: 400 });
      }
    }

    // Validate ssh_port if provided
    if (ssh_port !== undefined && !validatePort(ssh_port)) {
      return NextResponse.json({
        error: 'SSH port must be an integer between 1 and 65535'
      }, { status: 400 });
    }

    // Validate auth_type if provided
    if (auth_type !== undefined && !VALID_AUTH_TYPES.includes(auth_type as AuthType)) {
      return NextResponse.json({
        error: `Auth type must be one of: ${VALID_AUTH_TYPES.join(', ')}`
      }, { status: 400 });
    }

    // Validate auth-specific fields
    if (auth_type === 'key') {
      if (!private_key || typeof private_key !== 'string' || !private_key.trim()) {
        return NextResponse.json({
          error: 'Private key is required when auth_type is "key"'
        }, { status: 400 });
      }
    }

    // Build update object
    const updateData: any = {
      updatedAt: Date.now()
    };

    // Update basic fields
    if (name !== undefined) {
      updateData.name = name.trim();
    }
    if (host !== undefined) {
      updateData.host = host.trim();
    }
    if (ssh_user !== undefined) {
      updateData.sshUser = ssh_user.trim() || 'root';
    }
    if (ssh_port !== undefined) {
      updateData.sshPort = ssh_port;
    }
    if (root_path !== undefined) {
      updateData.rootPath = root_path.trim() || '/opt/apps';
    }
    if (env !== undefined) {
      updateData.env = env.trim() || 'prod';
    }

    // Handle auth type and credentials
    const finalAuthType = auth_type || existingTarget[0].authType;
    if (auth_type !== undefined) {
      updateData.authType = auth_type;
    }

    // Handle credential updates based on auth type
    if (finalAuthType === 'password') {
      // Clear key-based credentials when switching to password
      if (auth_type === 'password') {
        updateData.privateKey = null;
        updateData.passphrase = null;
      }
      
      if (password !== undefined) {
        if (password === '' || password === null) {
          updateData.password = null; // Clear password
        } else {
          updateData.password = encryptSecret(password); // Encrypt new password
        }
      }
    } else if (finalAuthType === 'key') {
      // Clear password when switching to key
      if (auth_type === 'key') {
        updateData.password = null;
      }
      
      if (private_key !== undefined) {
        if (private_key === '' || private_key === null) {
          updateData.privateKey = null; // Clear private key
        } else {
          updateData.privateKey = encryptSecret(private_key.trim()); // Encrypt new key
        }
      }
      
      if (passphrase !== undefined) {
        if (passphrase === '' || passphrase === null) {
          updateData.passphrase = null; // Clear passphrase
        } else {
          updateData.passphrase = encryptSecret(passphrase); // Encrypt new passphrase
        }
      }
    }

    const updatedTarget = await db.update(targets)
      .set(updateData)
      .where(eq(targets.id, parseInt(id)))
      .returning();

    const maskedTarget = maskTarget(updatedTarget[0]);

    await logSuccess(request, user.id, AUDIT_ACTIONS.TARGETS_UPDATE, 'targets', parseInt(id), {
      updatedFields: Object.keys(updateData).filter(key => key !== 'updatedAt')
    });

    return NextResponse.json(maskedTarget);

  } catch (error) {
    console.error('PUT error:', error);
    
    const roleError = handleRoleError(error);
    
    await logFailure(request, user?.id || null, AUDIT_ACTIONS.TARGETS_UPDATE, 'targets', 
      params.id ? parseInt(params.id) : null, {
        error: roleError.error
      });

    return NextResponse.json(roleError, { status: roleError.status });
  }
}

export async function DELETE(
  request: NextRequest,
  { params }: { params: { id: string } }
) {
  let user = null;
  try {
    user = await getCurrentUser(request);
    requireRole(user, 'delete');

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
      await logFailure(request, user.id, AUDIT_ACTIONS.TARGETS_DELETE, 'targets', parseInt(id), {
        error: 'Target not found'
      });

      return NextResponse.json({ error: 'Target not found' }, { status: 404 });
    }

    const deletedTarget = await db.delete(targets)
      .where(eq(targets.id, parseInt(id)))
      .returning();

    const maskedTarget = maskTarget(deletedTarget[0]);

    await logSuccess(request, user.id, AUDIT_ACTIONS.TARGETS_DELETE, 'targets', parseInt(id), {
      deletedTarget: {
        name: deletedTarget[0].name,
        host: deletedTarget[0].host
      }
    });

    return NextResponse.json({
      message: 'Target deleted successfully',
      deletedTarget: maskedTarget
    });
  } catch (error) {
    console.error('DELETE error:', error);
    
    const roleError = handleRoleError(error);
    
    await logFailure(request, user?.id || null, AUDIT_ACTIONS.TARGETS_DELETE, 'targets', 
      params.id ? parseInt(params.id) : null, {
        error: roleError.error
      });

    return NextResponse.json(roleError, { status: roleError.status });
  }
}
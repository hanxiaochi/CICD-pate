import { NextRequest, NextResponse } from 'next/server';
import { db } from '@/db';
import { targets } from '@/db/schema';
import { eq, desc, like, or, and } from 'drizzle-orm';
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

export async function GET(request: NextRequest) {
  let user = null;
  try {
    user = await getCurrentUser(request);
    requireRole(user, 'read');

    const { searchParams } = new URL(request.url);
    
    // Pagination parameters
    const page = Math.max(1, parseInt(searchParams.get('page') || '1'));
    const pageSize = Math.min(100, Math.max(1, parseInt(searchParams.get('pageSize') || '10')));
    const offset = (page - 1) * pageSize;
    
    // Search parameter
    const q = searchParams.get('q');

    let query = db.select().from(targets);

    // Apply search filter if provided
    if (q && q.trim()) {
      const searchTerm = `%${q.trim()}%`;
      query = query.where(
        or(
          like(targets.name, searchTerm),
          like(targets.host, searchTerm)
        )
      );
    }

    // Get total count for pagination
    const countQuery = db.select().from(targets);
    const totalResult = q && q.trim() 
      ? await countQuery.where(or(like(targets.name, `%${q.trim()}%`), like(targets.host, `%${q.trim()}%`)))
      : await countQuery;
    const total = totalResult.length;

    // Get paginated results
    const results = await query
      .orderBy(desc(targets.createdAt))
      .limit(pageSize)
      .offset(offset);

    // Mask sensitive data
    const maskedResults = results.map(maskTarget);

    const response = {
      items: maskedResults,
      total,
      page,
      pageSize,
      totalPages: Math.ceil(total / pageSize)
    };

    await logSuccess(request, user.id, AUDIT_ACTIONS.TARGETS_LIST, 'targets', null, {
      page,
      pageSize,
      search: q,
      resultCount: results.length
    });

    return NextResponse.json(response);
  } catch (error) {
    const roleError = handleRoleError(error);
    
    await logFailure(request, user?.id || null, AUDIT_ACTIONS.TARGETS_LIST, 'targets', null, {
      error: roleError.error
    });

    return NextResponse.json(roleError, { status: roleError.status });
  }
}

export async function POST(request: NextRequest) {
  let user = null;
  try {
    user = await getCurrentUser(request);
    requireRole(user, 'write');

    const body = await request.json();
    const {
      name,
      host,
      ssh_user = 'root',
      ssh_port = 22,
      root_path = '/opt/apps',
      auth_type = 'password',
      password,
      private_key,
      passphrase,
      env = 'prod',
      options = {}
    } = body;

    const { storeCredentials = true } = options;

    // Validate required fields
    if (!name || typeof name !== 'string' || !name.trim()) {
      await logFailure(request, user.id, AUDIT_ACTIONS.TARGETS_CREATE, 'targets', null, {
        error: 'Name is required'
      });
      
      return NextResponse.json({
        error: 'Name is required and must be a non-empty string'
      }, { status: 400 });
    }

    if (!host || typeof host !== 'string' || !host.trim()) {
      await logFailure(request, user.id, AUDIT_ACTIONS.TARGETS_CREATE, 'targets', null, {
        error: 'Host is required'
      });

      return NextResponse.json({
        error: 'Host is required and must be a non-empty string'
      }, { status: 400 });
    }

    // Validate ssh_port
    if (!validatePort(ssh_port)) {
      return NextResponse.json({
        error: 'SSH port must be an integer between 1 and 65535'
      }, { status: 400 });
    }

    // Validate auth_type
    if (!VALID_AUTH_TYPES.includes(auth_type as AuthType)) {
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

    // Prepare target data
    const now = Date.now();
    const targetData: any = {
      name: name.trim(),
      host: host.trim(),
      sshUser: ssh_user.trim() || 'root',
      sshPort: ssh_port,
      rootPath: root_path.trim() || '/opt/apps',
      authType: auth_type,
      env: env.trim() || 'prod',
      createdAt: now,
      updatedAt: now
    };

    // Handle credentials based on storeCredentials option
    if (storeCredentials) {
      // Encrypt and store credentials
      if (auth_type === 'password' && password) {
        targetData.password = encryptSecret(password);
      } else {
        targetData.password = null;
      }

      if (auth_type === 'key') {
        if (private_key && private_key.trim()) {
          targetData.privateKey = encryptSecret(private_key.trim());
        }
        if (passphrase && passphrase.trim()) {
          targetData.passphrase = encryptSecret(passphrase.trim());
        }
      } else {
        targetData.privateKey = null;
        targetData.passphrase = null;
      }
    } else {
      // Don't store credentials (validation/test only mode)
      targetData.password = null;
      targetData.privateKey = null;
      targetData.passphrase = null;
    }

    // Create target
    const newTarget = await db.insert(targets)
      .values(targetData)
      .returning();

    const maskedTarget = maskTarget(newTarget[0]);

    await logSuccess(request, user.id, AUDIT_ACTIONS.TARGETS_CREATE, 'targets', newTarget[0].id, {
      name: targetData.name,
      host: targetData.host,
      authType: targetData.authType,
      env: targetData.env,
      storeCredentials
    });

    return NextResponse.json(maskedTarget, { status: 201 });

  } catch (error) {
    console.error('POST /api/targets error:', error);
    
    const roleError = handleRoleError(error);
    
    await logFailure(request, user?.id || null, AUDIT_ACTIONS.TARGETS_CREATE, 'targets', null, {
      error: roleError.error
    });

    return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
  }
}
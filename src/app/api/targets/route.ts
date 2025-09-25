export const runtime = "nodejs";
import { NextRequest, NextResponse } from 'next/server';
import { db } from '@/db';
import { targets } from '@/db/schema';
import { desc, like, or } from 'drizzle-orm';
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

export async function GET(request: NextRequest) {
  try {
    requireAuth(request);

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

    return NextResponse.json(response);
  } catch (error) {
    console.error('GET /api/targets error:', error);
    
    if (error instanceof Error && error.message === 'Unauthorized') {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }
    
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
  }
}

export async function POST(request: NextRequest) {
  try {
    requireAuth(request);

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
      return NextResponse.json({
        error: 'Name is required and must be a non-empty string'
      }, { status: 400 });
    }

    if (!host || typeof host !== 'string' || !host.trim()) {
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
    if (auth_type !== 'password' && auth_type !== 'key') {
      return NextResponse.json({
        error: 'Auth type must be either "password" or "key"'
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
      hasPassword: false,
      hasPrivateKey: false,
      passwordEncrypted: null,
      privateKeyEncrypted: null,
      passphraseEncrypted: null,
      createdAt: now,
      updatedAt: now
    };

    // Handle credentials based on storeCredentials option
    if (storeCredentials) {
      // Encrypt and store credentials
      if (auth_type === 'password' && password && password.trim()) {
        targetData.passwordEncrypted = encryptCredential(password);
        targetData.hasPassword = true;
      }

      if (auth_type === 'key') {
        if (private_key && private_key.trim()) {
          targetData.privateKeyEncrypted = encryptCredential(private_key.trim());
          targetData.hasPrivateKey = true;
        }
        if (passphrase && passphrase.trim()) {
          targetData.passphraseEncrypted = encryptCredential(passphrase.trim());
        }
      }
    }

    // Create target
    const newTarget = await db.insert(targets)
      .values(targetData)
      .returning();

    const maskedTarget = maskTarget(newTarget[0]);

    return NextResponse.json(maskedTarget, { status: 201 });

  } catch (error) {
    console.error('POST /api/targets error:', error);
    
    if (error instanceof Error && error.message === 'Unauthorized') {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }
    
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
  }
}
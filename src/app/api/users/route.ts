import { NextRequest, NextResponse } from 'next/server';
import { db } from '@/db';
import { users } from '@/db/schema';
import { eq, like, and, or, desc } from 'drizzle-orm';

const VALID_ROLES = ['admin', 'developer', 'viewer'] as const;
const VALID_STATUSES = ['active', 'disabled'] as const;
const VALID_SCOPES = ['projects', 'pipelines', 'deployments', 'control'] as const;

type UserRole = typeof VALID_ROLES[number];
type UserStatus = typeof VALID_STATUSES[number];
type UserScope = typeof VALID_SCOPES[number];

function sanitizeScopes(scopes: any): UserScope[] {
  if (!Array.isArray(scopes)) return [];
  const validScopes = scopes
    .filter(scope => typeof scope === 'string' && VALID_SCOPES.includes(scope as UserScope))
    .map(scope => scope as UserScope);
  return [...new Set(validScopes)]; // Remove duplicates
}

function isValidEmail(email: string): boolean {
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return emailRegex.test(email);
}

export async function GET(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url);
    const id = searchParams.get('id');

    // Single user fetch
    if (id) {
      const userId = parseInt(id);
      if (isNaN(userId)) {
        return NextResponse.json({
          success: false,
          error: 'Valid ID is required'
        }, { status: 400 });
      }

      const user = await db.select()
        .from(users)
        .where(eq(users.id, userId))
        .limit(1);

      if (user.length === 0) {
        return NextResponse.json({
          success: false,
          error: 'User not found'
        }, { status: 404 });
      }

      return NextResponse.json({
        success: true,
        data: user[0]
      });
    }

    // List users with pagination and search
    const limit = Math.min(parseInt(searchParams.get('limit') || '10'), 100);
    const offset = parseInt(searchParams.get('offset') || '0');
    const search = searchParams.get('search');
    const role = searchParams.get('role');
    const status = searchParams.get('status');
    const sort = searchParams.get('sort') || 'createdAt';
    const order = searchParams.get('order') || 'desc';

    let query = db.select().from(users);

    // Build where conditions
    const conditions = [];

    if (search) {
      const searchTerm = `%${search.trim()}%`;
      conditions.push(
        or(
          like(users.name, searchTerm),
          like(users.email, searchTerm)
        )
      );
    }

    if (role && VALID_ROLES.includes(role as UserRole)) {
      conditions.push(eq(users.role, role));
    }

    if (status && VALID_STATUSES.includes(status as UserStatus)) {
      conditions.push(eq(users.status, status));
    }

    if (conditions.length > 0) {
      query = query.where(and(...conditions));
    }

    // Apply sorting
    const sortColumn = sort === 'name' ? users.name : 
                      sort === 'email' ? users.email :
                      sort === 'role' ? users.role :
                      sort === 'status' ? users.status :
                      sort === 'updatedAt' ? users.updatedAt :
                      users.createdAt;

    query = order === 'asc' ? 
      query.orderBy(sortColumn) : 
      query.orderBy(desc(sortColumn));

    const results = await query.limit(limit).offset(offset);

    return NextResponse.json({
      success: true,
      data: results
    });

  } catch (error) {
    console.error('GET /api/users error:', error);
    return NextResponse.json({
      success: false,
      error: 'Internal server error'
    }, { status: 500 });
  }
}

export async function POST(request: NextRequest) {
  try {
    const body = await request.json();
    const { name, email, role = 'viewer', scopes = [], status = 'active' } = body;

    // Validate required fields
    if (!name || typeof name !== 'string' || !name.trim()) {
      return NextResponse.json({
        success: false,
        error: 'Name is required and must be a non-empty string'
      }, { status: 400 });
    }

    if (!email || typeof email !== 'string' || !email.trim()) {
      return NextResponse.json({
        success: false,
        error: 'Email is required and must be a non-empty string'
      }, { status: 400 });
    }

    // Sanitize and validate inputs
    const sanitizedName = name.trim();
    const sanitizedEmail = email.trim().toLowerCase();

    if (!isValidEmail(sanitizedEmail)) {
      return NextResponse.json({
        success: false,
        error: 'Please provide a valid email address'
      }, { status: 400 });
    }

    if (!VALID_ROLES.includes(role as UserRole)) {
      return NextResponse.json({
        success: false,
        error: `Role must be one of: ${VALID_ROLES.join(', ')}`
      }, { status: 400 });
    }

    if (!VALID_STATUSES.includes(status as UserStatus)) {
      return NextResponse.json({
        success: false,
        error: `Status must be one of: ${VALID_STATUSES.join(', ')}`
      }, { status: 400 });
    }

    const sanitizedScopes = sanitizeScopes(scopes);

    // Check for email uniqueness
    const existingUser = await db.select()
      .from(users)
      .where(eq(users.email, sanitizedEmail))
      .limit(1);

    if (existingUser.length > 0) {
      return NextResponse.json({
        success: false,
        error: 'A user with this email already exists'
      }, { status: 409 });
    }

    // Create user
    const now = Date.now();
    const newUser = await db.insert(users)
      .values({
        name: sanitizedName,
        email: sanitizedEmail,
        role: role as UserRole,
        scopes: sanitizedScopes,
        status: status as UserStatus,
        createdAt: now,
        updatedAt: now
      })
      .returning();

    return NextResponse.json({
      success: true,
      data: newUser[0]
    }, { status: 201 });

  } catch (error) {
    console.error('POST /api/users error:', error);
    
    // Handle unique constraint violation
    if (error instanceof Error && error.message.includes('UNIQUE constraint failed: users.email')) {
      return NextResponse.json({
        success: false,
        error: 'A user with this email already exists'
      }, { status: 409 });
    }

    return NextResponse.json({
      success: false,
      error: 'Internal server error'
    }, { status: 500 });
  }
}

export async function PUT(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url);
    const id = searchParams.get('id');

    if (!id || isNaN(parseInt(id))) {
      return NextResponse.json({
        success: false,
        error: 'Valid ID is required'
      }, { status: 400 });
    }

    const userId = parseInt(id);
    const body = await request.json();
    const { name, email, role, scopes, status } = body;

    // Check if user exists
    const existingUser = await db.select()
      .from(users)
      .where(eq(users.id, userId))
      .limit(1);

    if (existingUser.length === 0) {
      return NextResponse.json({
        success: false,
        error: 'User not found'
      }, { status: 404 });
    }

    // Build update object
    const updates: any = {
      updatedAt: Date.now()
    };

    // Validate and sanitize fields if provided
    if (name !== undefined) {
      if (!name || typeof name !== 'string' || !name.trim()) {
        return NextResponse.json({
          success: false,
          error: 'Name must be a non-empty string'
        }, { status: 400 });
      }
      updates.name = name.trim();
    }

    if (email !== undefined) {
      if (!email || typeof email !== 'string' || !email.trim()) {
        return NextResponse.json({
          success: false,
          error: 'Email must be a non-empty string'
        }, { status: 400 });
      }

      const sanitizedEmail = email.trim().toLowerCase();
      if (!isValidEmail(sanitizedEmail)) {
        return NextResponse.json({
          success: false,
          error: 'Please provide a valid email address'
        }, { status: 400 });
      }

      // Check email uniqueness (exclude current user)
      if (sanitizedEmail !== existingUser[0].email) {
        const duplicateEmail = await db.select()
          .from(users)
          .where(and(
            eq(users.email, sanitizedEmail),
            eq(users.id, userId)
          ))
          .limit(1);

        if (duplicateEmail.length === 0) {
          const emailExists = await db.select()
            .from(users)
            .where(eq(users.email, sanitizedEmail))
            .limit(1);

          if (emailExists.length > 0) {
            return NextResponse.json({
              success: false,
              error: 'A user with this email already exists'
            }, { status: 409 });
          }
        }
      }

      updates.email = sanitizedEmail;
    }

    if (role !== undefined) {
      if (!VALID_ROLES.includes(role as UserRole)) {
        return NextResponse.json({
          success: false,
          error: `Role must be one of: ${VALID_ROLES.join(', ')}`
        }, { status: 400 });
      }
      updates.role = role;
    }

    if (status !== undefined) {
      if (!VALID_STATUSES.includes(status as UserStatus)) {
        return NextResponse.json({
          success: false,
          error: `Status must be one of: ${VALID_STATUSES.join(', ')}`
        }, { status: 400 });
      }
      updates.status = status;
    }

    if (scopes !== undefined) {
      updates.scopes = sanitizeScopes(scopes);
    }

    // Update user
    const updatedUser = await db.update(users)
      .set(updates)
      .where(eq(users.id, userId))
      .returning();

    return NextResponse.json({
      success: true,
      data: updatedUser[0]
    });

  } catch (error) {
    console.error('PUT /api/users error:', error);
    
    // Handle unique constraint violation
    if (error instanceof Error && error.message.includes('UNIQUE constraint failed: users.email')) {
      return NextResponse.json({
        success: false,
        error: 'A user with this email already exists'
      }, { status: 409 });
    }

    return NextResponse.json({
      success: false,
      error: 'Internal server error'
    }, { status: 500 });
  }
}

export async function DELETE(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url);
    const id = searchParams.get('id');

    if (!id || isNaN(parseInt(id))) {
      return NextResponse.json({
        success: false,
        error: 'Valid ID is required'
      }, { status: 400 });
    }

    const userId = parseInt(id);

    // Check if user exists
    const existingUser = await db.select()
      .from(users)
      .where(eq(users.id, userId))
      .limit(1);

    if (existingUser.length === 0) {
      return NextResponse.json({
        success: false,
        error: 'User not found'
      }, { status: 404 });
    }

    // Delete user
    const deletedUser = await db.delete(users)
      .where(eq(users.id, userId))
      .returning();

    return NextResponse.json({
      success: true,
      data: deletedUser[0]
    });

  } catch (error) {
    console.error('DELETE /api/users error:', error);
    return NextResponse.json({
      success: false,
      error: 'Internal server error'
    }, { status: 500 });
  }
}
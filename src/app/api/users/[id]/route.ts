import { NextRequest, NextResponse } from 'next/server';
import { db } from '@/db';
import { users } from '@/db/schema';
import { eq, and } from 'drizzle-orm';

type UserRole = 'admin' | 'developer' | 'viewer';
type UserStatus = 'active' | 'disabled';
type UserScope = 'projects' | 'pipelines' | 'deployments' | 'control';

const VALID_ROLES: UserRole[] = ['admin', 'developer', 'viewer'];
const VALID_STATUSES: UserStatus[] = ['active', 'disabled'];
const VALID_SCOPES: UserScope[] = ['projects', 'pipelines', 'deployments', 'control'];

interface UpdateUserData {
  name?: string;
  email?: string;
  role?: UserRole;
  scopes?: UserScope[];
  status?: UserStatus;
}

export async function GET(
  request: NextRequest,
  { params }: { params: { id: string } }
) {
  try {
    const { id } = params;

    if (!id || isNaN(parseInt(id))) {
      return NextResponse.json({
        success: false,
        error: "Valid ID is required"
      }, { status: 400 });
    }

    const user = await db.select()
      .from(users)
      .where(eq(users.id, parseInt(id)))
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
  } catch (error) {
    console.error('GET error:', error);
    return NextResponse.json({
      success: false,
      error: 'Internal server error: ' + error
    }, { status: 500 });
  }
}

export async function PATCH(
  request: NextRequest,
  { params }: { params: { id: string } }
) {
  try {
    const { id } = params;

    if (!id || isNaN(parseInt(id))) {
      return NextResponse.json({
        success: false,
        error: "Valid ID is required"
      }, { status: 400 });
    }

    const requestBody = await request.json();
    const { name, email, role, scopes, status } = requestBody as UpdateUserData;

    // Check if user exists
    const existingUser = await db.select()
      .from(users)
      .where(eq(users.id, parseInt(id)))
      .limit(1);

    if (existingUser.length === 0) {
      return NextResponse.json({
        success: false,
        error: 'User not found'
      }, { status: 404 });
    }

    // Validate provided fields
    const updates: Partial<UpdateUserData> = {};

    if (name !== undefined) {
      if (typeof name !== 'string' || name.trim().length === 0) {
        return NextResponse.json({
          success: false,
          error: "Name must be a non-empty string"
        }, { status: 400 });
      }
      updates.name = name.trim();
    }

    if (email !== undefined) {
      if (typeof email !== 'string' || !email.includes('@')) {
        return NextResponse.json({
          success: false,
          error: "Valid email is required"
        }, { status: 400 });
      }
      
      const normalizedEmail = email.toLowerCase().trim();
      
      // Check email uniqueness if email is being changed
      if (normalizedEmail !== existingUser[0].email) {
        const emailExists = await db.select()
          .from(users)
          .where(eq(users.email, normalizedEmail))
          .limit(1);

        if (emailExists.length > 0) {
          return NextResponse.json({
            success: false,
            error: "Email already exists"
          }, { status: 409 });
        }
      }
      
      updates.email = normalizedEmail;
    }

    if (role !== undefined) {
      if (!VALID_ROLES.includes(role)) {
        return NextResponse.json({
          success: false,
          error: `Role must be one of: ${VALID_ROLES.join(', ')}`
        }, { status: 400 });
      }
      updates.role = role;
    }

    if (status !== undefined) {
      if (!VALID_STATUSES.includes(status)) {
        return NextResponse.json({
          success: false,
          error: `Status must be one of: ${VALID_STATUSES.join(', ')}`
        }, { status: 400 });
      }
      updates.status = status;
    }

    if (scopes !== undefined) {
      if (!Array.isArray(scopes)) {
        return NextResponse.json({
          success: false,
          error: "Scopes must be an array"
        }, { status: 400 });
      }

      // Sanitize scopes to unique values from valid set only
      const sanitizedScopes = [...new Set(scopes.filter(scope => VALID_SCOPES.includes(scope)))];
      updates.scopes = sanitizedScopes;
    }

    // If no valid updates provided
    if (Object.keys(updates).length === 0) {
      return NextResponse.json({
        success: false,
        error: "No valid fields provided for update"
      }, { status: 400 });
    }

    // Update user
    const updatedUser = await db.update(users)
      .set({
        ...updates,
        updatedAt: Date.now()
      })
      .where(eq(users.id, parseInt(id)))
      .returning();

    return NextResponse.json({
      success: true,
      data: updatedUser[0]
    });
  } catch (error) {
    console.error('PATCH error:', error);
    return NextResponse.json({
      success: false,
      error: 'Internal server error: ' + error
    }, { status: 500 });
  }
}

export async function DELETE(
  request: NextRequest,
  { params }: { params: { id: string } }
) {
  try {
    const { id } = params;

    if (!id || isNaN(parseInt(id))) {
      return NextResponse.json({
        success: false,
        error: "Valid ID is required"
      }, { status: 400 });
    }

    // Check if user exists
    const existingUser = await db.select()
      .from(users)
      .where(eq(users.id, parseInt(id)))
      .limit(1);

    if (existingUser.length === 0) {
      return NextResponse.json({
        success: false,
        error: 'User not found'
      }, { status: 404 });
    }

    // Delete user
    const deletedUser = await db.delete(users)
      .where(eq(users.id, parseInt(id)))
      .returning();

    return NextResponse.json({
      success: true,
      data: deletedUser[0]
    });
  } catch (error) {
    console.error('DELETE error:', error);
    return NextResponse.json({
      success: false,
      error: 'Internal server error: ' + error
    }, { status: 500 });
  }
}
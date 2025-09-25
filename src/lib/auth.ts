import { NextRequest } from 'next/server';
import { db } from '@/db';
import { users } from '@/db/schema';
import { eq } from 'drizzle-orm';

// Role constants
export const ROLES = {
  ADMIN: 'admin',
  DEVELOPER: 'developer',
  VIEWER: 'viewer'
} as const;

// User interface
export interface User {
  id: number;
  name: string;
  email: string;
  role: string;
  scopes: string[];
  status: string;
  createdAt: number;
  updatedAt: number;
}

// Permission checking functions
export function canRead(role: string): boolean {
  return [ROLES.ADMIN, ROLES.DEVELOPER, ROLES.VIEWER].includes(role as any);
}

export function canWrite(role: string): boolean {
  return [ROLES.ADMIN, ROLES.DEVELOPER].includes(role as any);
}

export function canDelete(role: string): boolean {
  return role === ROLES.ADMIN;
}

export function canTest(role: string): boolean {
  return [ROLES.ADMIN, ROLES.DEVELOPER].includes(role as any);
}

// Get current user from request
export async function getCurrentUser(request: NextRequest): Promise<User | null> {
  try {
    // Get Authorization header
    const authHeader = request.headers.get('authorization');
    
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return null;
    }

    // Extract token (treating as email for simplicity)
    const token = authHeader.substring(7); // Remove "Bearer " prefix
    
    if (!token) {
      return null;
    }

    // Query user by email (token)
    const userResult = await db.select()
      .from(users)
      .where(eq(users.email, token))
      .limit(1);

    if (userResult.length === 0) {
      return null;
    }

    const user = userResult[0];

    // Check if user is active
    if (user.status !== 'active') {
      return null;
    }

    return {
      id: user.id,
      name: user.name,
      email: user.email,
      role: user.role,
      scopes: Array.isArray(user.scopes) ? user.scopes : [],
      status: user.status,
      createdAt: user.createdAt,
      updatedAt: user.updatedAt
    };

  } catch (error) {
    console.error('getCurrentUser error:', error);
    return null;
  }
}

// Role requirement checking with error throwing
export function requireRole(
  user: User | null, 
  requiredPermission: 'read' | 'write' | 'delete' | 'test'
): void {
  if (!user) {
    throw new Error(JSON.stringify({
      error: 'Authentication required',
      code: 'AUTHENTICATION_REQUIRED',
      status: 401
    }));
  }

  let hasPermission = false;

  switch (requiredPermission) {
    case 'read':
      hasPermission = canRead(user.role);
      break;
    case 'write':
      hasPermission = canWrite(user.role);
      break;
    case 'delete':
      hasPermission = canDelete(user.role);
      break;
    case 'test':
      hasPermission = canTest(user.role);
      break;
    default:
      hasPermission = false;
  }

  if (!hasPermission) {
    throw new Error(JSON.stringify({
      error: `Insufficient permissions. Required: ${requiredPermission}, Current role: ${user.role}`,
      code: 'INSUFFICIENT_PERMISSIONS',
      status: 403
    }));
  }
}

// Helper function to handle role requirement errors in API routes
export function handleRoleError(error: any) {
  if (error.message) {
    try {
      const parsedError = JSON.parse(error.message);
      if (parsedError.status) {
        return {
          error: parsedError.error,
          code: parsedError.code,
          status: parsedError.status
        };
      }
    } catch (parseError) {
      // If not a structured error, return generic 500
    }
  }
  
  return {
    error: 'Internal server error',
    code: 'INTERNAL_ERROR',
    status: 500
  };
}

// Utility function to check if user has specific role
export function hasRole(user: User | null, role: string): boolean {
  return user?.role === role;
}

// Utility function to check if user has any of the specified roles
export function hasAnyRole(user: User | null, roles: string[]): boolean {
  if (!user) return false;
  return roles.includes(user.role);
}

// Utility function to get user permissions summary
export function getUserPermissions(user: User | null) {
  if (!user) {
    return {
      canRead: false,
      canWrite: false,
      canDelete: false,
      canTest: false
    };
  }

  return {
    canRead: canRead(user.role),
    canWrite: canWrite(user.role),
    canDelete: canDelete(user.role),
    canTest: canTest(user.role)
  };
}
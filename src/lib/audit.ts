import { NextRequest } from 'next/server';
import { db } from '@/db';
import { auditLogs } from '@/db/schema';

// Audit action constants for consistency
export const AUDIT_ACTIONS = {
  // Targets
  TARGETS_LIST: 'targets.list',
  TARGETS_CREATE: 'targets.create',
  TARGETS_UPDATE: 'targets.update',
  TARGETS_DELETE: 'targets.delete',
  TARGETS_FS: 'targets.fs',
  TARGETS_PROCESSES: 'targets.processes',
  TARGETS_TEST_SSH: 'targets.test_ssh',
  
  // Users
  USERS_LIST: 'users.list',
  USERS_CREATE: 'users.create',
  USERS_UPDATE: 'users.update',
  USERS_DELETE: 'users.delete',
  
  // Authentication
  AUTH_LOGIN: 'auth.login',
  AUTH_LOGOUT: 'auth.logout',
  AUTH_REGISTER: 'auth.register',
  
  // System
  SYSTEM_HEALTH: 'system.health',
  SYSTEM_CONFIG: 'system.config',
} as const;

export type AuditAction = typeof AUDIT_ACTIONS[keyof typeof AUDIT_ACTIONS];

interface LogAuditParams {
  userId: number | null;
  action: string;
  resource: string;
  resourceId?: number | null;
  success: boolean;
  details?: any;
  ip?: string;
  userAgent?: string;
}

export async function logAudit({
  userId,
  action,
  resource,
  resourceId = null,
  success,
  details,
  ip,
  userAgent,
}: LogAuditParams): Promise<void> {
  try {
    // Process details - stringify if object, keep as string if already string
    let processedDetails: string | null = null;
    if (details !== undefined && details !== null) {
      if (typeof details === 'object') {
        try {
          processedDetails = JSON.stringify(details);
        } catch (error) {
          processedDetails = String(details);
        }
      } else {
        processedDetails = String(details);
      }
    }

    await db.insert(auditLogs).values({
      userId,
      action,
      resource,
      resourceId,
      success: success ? 1 : 0, // Convert boolean to integer
      details: processedDetails,
      ip: ip || null,
      userAgent: userAgent || null,
      createdAt: Date.now(), // Using timestamp in milliseconds
    });
  } catch (error) {
    // Log error but don't throw - audit logging shouldn't break the main operation
    console.error('Failed to log audit entry:', {
      error: error instanceof Error ? error.message : String(error),
      userId,
      action,
      resource,
      resourceId,
      success,
    });
  }
}

export interface ClientInfo {
  ip: string | null;
  userAgent: string | null;
}

export function getClientInfo(request: NextRequest): ClientInfo {
  // Extract IP address - check forwarded headers first for proxy scenarios
  let ip: string | null = null;
  
  // Check common forwarded IP headers
  const forwardedFor = request.headers.get('x-forwarded-for');
  const realIp = request.headers.get('x-real-ip');
  const cfConnectingIp = request.headers.get('cf-connecting-ip'); // Cloudflare
  
  if (forwardedFor) {
    // x-forwarded-for can contain multiple IPs, take the first one
    ip = forwardedFor.split(',')[0].trim();
  } else if (realIp) {
    ip = realIp.trim();
  } else if (cfConnectingIp) {
    ip = cfConnectingIp.trim();
  } else {
    // Fallback to connection remote address if available
    // Note: In serverless environments, this might not be available
    ip = request.ip || null;
  }

  // Extract User-Agent
  const userAgent = request.headers.get('user-agent') || null;

  return {
    ip,
    userAgent,
  };
}

// Helper function to log audit with client info extracted from request
export async function logAuditWithRequest(
  request: NextRequest,
  params: Omit<LogAuditParams, 'ip' | 'userAgent'>
): Promise<void> {
  const clientInfo = getClientInfo(request);
  
  await logAudit({
    ...params,
    ip: clientInfo.ip,
    userAgent: clientInfo.userAgent,
  });
}

// Helper function to create audit log entry for successful operations
export async function logSuccess(
  request: NextRequest,
  userId: number | null,
  action: string,
  resource: string,
  resourceId?: number | null,
  details?: any
): Promise<void> {
  await logAuditWithRequest(request, {
    userId,
    action,
    resource,
    resourceId,
    success: true,
    details,
  });
}

// Helper function to create audit log entry for failed operations
export async function logFailure(
  request: NextRequest,
  userId: number | null,
  action: string,
  resource: string,
  resourceId?: number | null,
  details?: any
): Promise<void> {
  await logAuditWithRequest(request, {
    userId,
    action,
    resource,
    resourceId,
    success: false,
    details,
  });
}
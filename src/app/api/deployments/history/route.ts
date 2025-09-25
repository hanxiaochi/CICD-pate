import { NextRequest, NextResponse } from 'next/server';
import { db } from '@/db';
import { deployments, projects, packages, targets, systems, deploymentSteps } from '@/db/schema';
import { eq, desc } from 'drizzle-orm';

export async function GET(request: NextRequest) {
  try {
    // Check for Bearer token authorization
    const authHeader = request.headers.get('authorization');
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return NextResponse.json({ 
        error: 'Bearer token required',
        code: 'MISSING_BEARER_TOKEN' 
      }, { status: 401 });
    }

    const token = authHeader.substring(7);
    if (!token) {
      return NextResponse.json({ 
        error: 'Invalid bearer token',
        code: 'INVALID_BEARER_TOKEN' 
      }, { status: 401 });
    }

    // Get latest 50 deployments with joins
    const deploymentsWithDetails = await db
      .select({
        id: deployments.id,
        status: deployments.status,
        startedAt: deployments.startedAt,
        finishedAt: deployments.finishedAt,
        error: deployments.error,
        releasePath: deployments.releasePath,
        projectName: projects.name,
        packageName: packages.name,
        targetName: targets.name,
        systemName: systems.name,
      })
      .from(deployments)
      .innerJoin(projects, eq(deployments.projectId, projects.id))
      .innerJoin(packages, eq(deployments.packageId, packages.id))
      .innerJoin(targets, eq(deployments.targetId, targets.id))
      .innerJoin(systems, eq(deployments.systemId, systems.id))
      .orderBy(desc(deployments.startedAt))
      .limit(50);

    // Get deployment steps for all deployments
    const deploymentIds = deploymentsWithDetails.map(d => d.id);
    let allSteps: any[] = [];
    
    if (deploymentIds.length > 0) {
      allSteps = await db
        .select({
          id: deploymentSteps.id,
          deploymentId: deploymentSteps.deploymentId,
          key: deploymentSteps.key,
          label: deploymentSteps.label,
          ok: deploymentSteps.ok,
          log: deploymentSteps.log,
          createdAt: deploymentSteps.createdAt,
        })
        .from(deploymentSteps)
        .where(eq(deploymentSteps.deploymentId, deploymentIds[0]));

      // Get steps for remaining deployments
      for (let i = 1; i < deploymentIds.length; i++) {
        const steps = await db
          .select({
            id: deploymentSteps.id,
            deploymentId: deploymentSteps.deploymentId,
            key: deploymentSteps.key,
            label: deploymentSteps.label,
            ok: deploymentSteps.ok,
            log: deploymentSteps.log,
            createdAt: deploymentSteps.createdAt,
          })
          .from(deploymentSteps)
          .where(eq(deploymentSteps.deploymentId, deploymentIds[i]));
        
        allSteps = allSteps.concat(steps);
      }
    }

    // Group steps by deployment ID
    const stepsByDeployment = allSteps.reduce((acc, step) => {
      if (!acc[step.deploymentId]) {
        acc[step.deploymentId] = [];
      }
      acc[step.deploymentId].push({
        id: step.id,
        key: step.key,
        label: step.label,
        ok: step.ok,
        log: step.log,
        createdAt: step.createdAt,
      });
      return acc;
    }, {} as Record<number, any[]>);

    // Combine deployments with their steps
    const result = deploymentsWithDetails.map(deployment => ({
      id: deployment.id,
      status: deployment.status,
      startedAt: deployment.startedAt,
      finishedAt: deployment.finishedAt,
      error: deployment.error,
      projectName: deployment.projectName,
      packageName: deployment.packageName,
      targetName: deployment.targetName,
      systemName: deployment.systemName,
      releasePath: deployment.releasePath,
      steps: stepsByDeployment[deployment.id] || [],
    }));

    return NextResponse.json(result);

  } catch (error) {
    console.error('GET error:', error);
    return NextResponse.json({ 
      error: 'Internal server error: ' + error 
    }, { status: 500 });
  }
}

export async function POST(request: NextRequest) {
  return NextResponse.json({ 
    error: 'Method not allowed',
    code: 'METHOD_NOT_ALLOWED' 
  }, { status: 405 });
}

export async function PUT(request: NextRequest) {
  return NextResponse.json({ 
    error: 'Method not allowed',
    code: 'METHOD_NOT_ALLOWED' 
  }, { status: 405 });
}

export async function DELETE(request: NextRequest) {
  return NextResponse.json({ 
    error: 'Method not allowed',
    code: 'METHOD_NOT_ALLOWED' 
  }, { status: 405 });
}
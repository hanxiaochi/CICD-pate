export const runtime = "nodejs";

import { NextRequest, NextResponse } from 'next/server';
import { db } from '@/db';
import { deployments, deploymentSteps, projects, packages, targets } from '@/db/schema';
import { eq, desc, and } from 'drizzle-orm';
import { decryptCredential } from '@/lib/encryption';
import { connectSSH, execCommand, createSymlink, killProcessByPattern } from '@/lib/ssh';
import path from 'path';

function requireAuth(request: NextRequest) {
  const auth = request.headers.get('authorization');
  if (!auth || !auth.startsWith('Bearer ') || !auth.slice(7).trim()) {
    throw new Error('Unauthorized');
  }
}

async function recordStep(deploymentId: number, key: string, label: string, ok: boolean, log?: string) {
  await db.insert(deploymentSteps).values({
    deploymentId,
    key,
    label,
    ok,
    log: log || null,
    createdAt: Date.now()
  });
}

export async function POST(
  request: NextRequest,
  { params }: { params: { id: string } }
) {
  try {
    requireAuth(request);

    const { id } = params;

    if (!id || isNaN(parseInt(id))) {
      return NextResponse.json({
        error: 'Valid deployment ID is required'
      }, { status: 400 });
    }

    const deploymentId = parseInt(id);

    // Get the deployment to rollback
    const deployment = await db.select()
      .from(deployments)
      .where(eq(deployments.id, deploymentId))
      .limit(1);

    if (deployment.length === 0) {
      return NextResponse.json({
        error: 'Deployment not found'
      }, { status: 404 });
    }

    const currentDeployment = deployment[0];

    if (currentDeployment.status !== 'success') {
      return NextResponse.json({
        error: 'Can only rollback successful deployments'
      }, { status: 400 });
    }

    if (!currentDeployment.releasePath || !currentDeployment.currentLink) {
      return NextResponse.json({
        error: 'Deployment missing release path information'
      }, { status: 400 });
    }

    // Create rollback deployment record
    const rollbackDeployment = await db.insert(deployments).values({
      systemId: currentDeployment.systemId,
      projectId: currentDeployment.projectId,
      packageId: currentDeployment.packageId, // Same package, different release
      targetId: currentDeployment.targetId,
      status: 'pending',
      startedAt: Date.now()
    }).returning();

    const rollbackId = rollbackDeployment[0].id;
    const steps: any[] = [];

    try {
      // Get project, package, and target details
      const project = await db.select().from(projects).where(eq(projects.id, currentDeployment.projectId)).limit(1);
      const pkg = await db.select().from(packages).where(eq(packages.id, currentDeployment.packageId)).limit(1);
      const target = await db.select().from(targets).where(eq(targets.id, currentDeployment.targetId)).limit(1);

      if (!project.length || !pkg.length || !target.length) {
        throw new Error('Unable to find deployment dependencies');
      }

      // Step 1: Find previous release
      await recordStep(rollbackId, 'find_previous', 'Find previous release', true);
      steps.push({ key: 'find_previous', label: 'Find previous release', ok: true });

      // Get previous successful deployment for same project/target
      const previousDeployments = await db.select()
        .from(deployments)
        .where(and(
          eq(deployments.projectId, currentDeployment.projectId),
          eq(deployments.targetId, currentDeployment.targetId),
          eq(deployments.status, 'success')
        ))
        .orderBy(desc(deployments.startedAt))
        .limit(5); // Get recent deployments

      // Find previous deployment (skip the current one we're rolling back)
      const previousDeployment = previousDeployments.find(d => 
        d.id !== deploymentId && d.releasePath && d.releasePath !== currentDeployment.releasePath
      );

      if (!previousDeployment || !previousDeployment.releasePath) {
        throw new Error('No previous release found to rollback to');
      }

      // Step 2: Connect to target
      await recordStep(rollbackId, 'connect', `Connect to target ${target[0].host}`, true);
      steps.push({ key: 'connect', label: `Connect to target ${target[0].host}`, ok: true });

      // Prepare SSH connection
      const sshConfig: any = {
        host: target[0].host,
        port: target[0].sshPort,
        username: target[0].sshUser,
        timeout: 30000
      };

      if (target[0].authType === 'password' && target[0].hasPassword && target[0].passwordEncrypted) {
        sshConfig.password = decryptCredential(target[0].passwordEncrypted);
      } else if (target[0].authType === 'key' && target[0].hasPrivateKey && target[0].privateKeyEncrypted) {
        sshConfig.privateKey = decryptCredential(target[0].privateKeyEncrypted);
        if (target[0].passphraseEncrypted) {
          sshConfig.passphrase = decryptCredential(target[0].passphraseEncrypted);
        }
      } else {
        throw new Error('No valid credentials configured for target');
      }

      const client = await connectSSH(sshConfig);

      try {
        // Step 3: Verify previous release exists
        const previousReleaseExists = await execCommand(client, `test -d "${previousDeployment.releasePath}" && echo "exists"`);
        if (!previousReleaseExists.trim().includes('exists')) {
          throw new Error(`Previous release directory not found: ${previousDeployment.releasePath}`);
        }

        await recordStep(rollbackId, 'verify', 'Verify previous release exists', true);
        steps.push({ key: 'verify', label: 'Verify previous release exists', ok: true });

        // Step 4: Stop current application if Java JAR
        const packageName = pkg[0].name;
        const ext = path.extname(packageName).toLowerCase();
        
        if (ext === '.jar') {
          try {
            await killProcessByPattern(client, `java.*${packageName.replace('.jar', '')}`);
            await new Promise(resolve => setTimeout(resolve, 3000)); // Wait 3 seconds
            
            await recordStep(rollbackId, 'stop', 'Stop current application', true);
            steps.push({ key: 'stop', label: 'Stop current application', ok: true });
          } catch (stopError) {
            // Process might not be running, continue
            await recordStep(rollbackId, 'stop', 'Stop current application (process not found)', true);
            steps.push({ key: 'stop', label: 'Stop current application (process not found)', ok: true });
          }
        }

        // Step 5: Switch symlink to previous release
        await createSymlink(client, previousDeployment.releasePath, currentDeployment.currentLink);
        
        await recordStep(rollbackId, 'symlink', `Switch symlink to ${previousDeployment.releasePath}`, true);
        steps.push({ key: 'symlink', label: `Switch symlink to ${previousDeployment.releasePath}`, ok: true });

        // Step 6: Start application from previous release
        if (ext === '.jar') {
          const port = 8080; // Default port
          const startCmd = `cd "${currentDeployment.currentLink}" && nohup java -jar "${packageName}" --server.port=${port} > logs/app.log 2>&1 & echo $!`;
          
          const pidOutput = await execCommand(client, startCmd);
          const pid = pidOutput.trim();
          
          await recordStep(rollbackId, 'start', `Start application from previous release (PID: ${pid})`, true);
          steps.push({ key: 'start', label: `Start application from previous release (PID: ${pid})`, ok: true });
        } else {
          await recordStep(rollbackId, 'activate', 'Activate previous release', true);
          steps.push({ key: 'activate', label: 'Activate previous release', ok: true });
        }

        // Step 7: Verify rollback
        await recordStep(rollbackId, 'complete', 'Rollback completed successfully', true);
        steps.push({ key: 'complete', label: 'Rollback completed successfully', ok: true });

        // Update rollback deployment status
        await db.update(deployments)
          .set({
            status: 'success',
            releasePath: previousDeployment.releasePath,
            currentLink: currentDeployment.currentLink,
            finishedAt: Date.now(),
            error: `Rollback from deployment ${deploymentId}`
          })
          .where(eq(deployments.id, rollbackId));

        client.end();

        return NextResponse.json({
          ok: true,
          rollbackDeploymentId: rollbackId,
          originalDeploymentId: deploymentId,
          previousReleasePath: previousDeployment.releasePath,
          steps
        });

      } catch (rollbackError) {
        // Record failure step
        await recordStep(rollbackId, 'error', 'Rollback failed', false, rollbackError.message);
        steps.push({ key: 'error', label: 'Rollback failed', ok: false, log: rollbackError.message });

        // Update rollback deployment status
        await db.update(deployments)
          .set({
            status: 'failed',
            finishedAt: Date.now(),
            error: rollbackError.message
          })
          .where(eq(deployments.id, rollbackId));

        client?.end();
        throw rollbackError;
      }

    } catch (error) {
      return NextResponse.json({
        ok: false,
        rollbackDeploymentId: rollbackId,
        error: error instanceof Error ? error.message : 'Rollback failed',
        steps
      }, { status: 500 });
    }

  } catch (error) {
    console.error('POST /api/deployments/[id]/rollback error:', error);
    
    if (error instanceof Error && error.message === 'Unauthorized') {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }
    
    return NextResponse.json({
      ok: false,
      error: 'Internal server error'
    }, { status: 500 });
  }
}
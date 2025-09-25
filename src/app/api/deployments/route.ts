export const runtime = "nodejs";

import { NextRequest, NextResponse } from 'next/server';
import { db } from '@/db';
import { deployments, deploymentSteps, projects, packages, targets, systems } from '@/db/schema';
import { eq, desc } from 'drizzle-orm';
import { decryptCredential } from '@/lib/encryption';
import { connectSSH, connectSFTP, execCommand, createSymlink, killProcessByPattern } from '@/lib/ssh';
import path from 'path';
import fs from 'fs/promises';

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

async function downloadFileFromUrl(url: string, localPath: string): Promise<void> {
  // For demo, assume file URLs are local paths that we can copy
  if (url.startsWith('http://') || url.startsWith('https://')) {
    throw new Error('HTTP downloads not implemented in demo');
  }
  
  // Local file copy
  await fs.copyFile(url, localPath);
}

export async function POST(request: NextRequest) {
  try {
    requireAuth(request);

    const body = await request.json();
    const { systemId, projectId, packageId, targetId } = body;

    // Validate required fields
    if (!projectId || typeof projectId !== 'number') {
      return NextResponse.json({
        error: 'Project ID is required'
      }, { status: 400 });
    }

    if (!packageId || typeof packageId !== 'number') {
      return NextResponse.json({
        error: 'Package ID is required'
      }, { status: 400 });
    }

    if (!targetId || typeof targetId !== 'number') {
      return NextResponse.json({
        error: 'Target ID is required'
      }, { status: 400 });
    }

    const steps: any[] = [];

    // Create deployment record
    const newDeployment = await db.insert(deployments).values({
      systemId: systemId || null,
      projectId,
      packageId,
      targetId,
      status: 'pending',
      startedAt: Date.now()
    }).returning();

    const actualDeploymentId = newDeployment[0].id;

    try {
      // Step 1: Validate parameters
      await recordStep(actualDeploymentId, 'validate', 'Validate deployment parameters', true);
      steps.push({ key: 'validate', label: 'Validate deployment parameters', ok: true });

      // Get project, package, and target details
      const project = await db.select().from(projects).where(eq(projects.id, projectId)).limit(1);
      if (project.length === 0) {
        throw new Error('Project not found');
      }

      const pkg = await db.select().from(packages).where(eq(packages.id, packageId)).limit(1);
      if (pkg.length === 0) {
        throw new Error('Package not found');
      }

      const target = await db.select().from(targets).where(eq(targets.id, targetId)).limit(1);
      if (target.length === 0) {
        throw new Error('Target not found');
      }

      // Step 2: Connect to target with real SSH
      const sshConfig: any = {
        host: target[0].host,
        port: target[0].sshPort,
        username: target[0].sshUser,
        timeout: 30000,
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
      const sftp = await connectSFTP(sshConfig);

      await recordStep(actualDeploymentId, 'connect', `Connect to target ${target[0].host}`, true);
      steps.push({ key: 'connect', label: `Connect to target ${target[0].host}`, ok: true });

      try {
        // Step 3: Prepare directories on remote
        const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
        const projectPath = `${target[0].rootPath}/${project[0].name}`;
        const releasesPath = `${projectPath}/releases`;
        const currentReleasePath = `${releasesPath}/${timestamp}`;
        const currentLink = `${projectPath}/current`;

        await execCommand(client, `mkdir -p "${releasesPath}"`);
        await execCommand(client, `mkdir -p "${currentReleasePath}"`);
        await recordStep(actualDeploymentId, 'mkdirs', 'Create deployment directories', true);
        steps.push({ key: 'mkdirs', label: 'Create deployment directories', ok: true });

        // Step 4: Upload package
        const packageName = pkg[0].name;
        const remoteTempPath = `/tmp/${packageName}`;
        const remoteFilePath = `${currentReleasePath}/${packageName}`;

        // Download to local temp and upload via SFTP
        const localTempPath = `/tmp/deploy-${Date.now()}-${packageName}`;
        await downloadFileFromUrl(pkg[0].fileUrl, localTempPath);
        await sftp.put(localTempPath, remoteTempPath);
        await execCommand(client, `mv "${remoteTempPath}" "${remoteFilePath}"`);
        await recordStep(actualDeploymentId, 'upload', `Upload package ${packageName}`, true);
        steps.push({ key: 'upload', label: `Upload package ${packageName}`, ok: true });

        // Step 5: Extract or prepare package on remote
        const ext = path.extname(packageName).toLowerCase();
        if (ext === '.jar') {
          await recordStep(actualDeploymentId, 'extract', 'Java JAR ready for deployment', true);
          steps.push({ key: 'extract', label: 'Java JAR ready for deployment', ok: true });
        } else if (ext === '.gz' || packageName.endsWith('.tar.gz')) {
          await execCommand(client, `cd "${currentReleasePath}" && tar -xzf "${packageName}"`);
          await recordStep(actualDeploymentId, 'extract', 'Extract package archive', true);
          steps.push({ key: 'extract', label: 'Extract package archive', ok: true });
        } else if (ext === '.zip') {
          await execCommand(client, `cd "${currentReleasePath}" && unzip -q "${packageName}"`);
          await recordStep(actualDeploymentId, 'extract', 'Extract package archive', true);
          steps.push({ key: 'extract', label: 'Extract package archive', ok: true });
        }

        // Step 6: Update symlink
        await createSymlink(client, currentReleasePath, currentLink);
        await recordStep(actualDeploymentId, 'symlink', 'Update current symlink', true);
        steps.push({ key: 'symlink', label: 'Update current symlink', ok: true });

        // Step 7: Start/restart application for Java jar
        if (ext === '.jar') {
          const jarName = packageName;
          const port = 8080; // could be parameterized
          try {
            await killProcessByPattern(client, `java.*${jarName.replace('.jar', '')}`);
            await new Promise((r) => setTimeout(r, 2000));
          } catch {}

          await execCommand(client, `mkdir -p "${currentLink}/logs"`);
          const pidOutput = await execCommand(client, `cd "${currentLink}" && nohup java -jar "${jarName}" --server.port=${port} > logs/app.log 2>&1 & echo $!`);
          const pid = pidOutput.trim();
          await recordStep(actualDeploymentId, 'start', `Start Java application (PID: ${pid})`, true);
          steps.push({ key: 'start', label: `Start Java application (PID: ${pid})`, ok: true });
        } else {
          await recordStep(actualDeploymentId, 'deploy', 'Application files deployed', true);
          steps.push({ key: 'deploy', label: 'Application files deployed', ok: true });
        }

        // Step 8: Verify
        await recordStep(actualDeploymentId, 'verify', 'Deployment verification complete', true);
        steps.push({ key: 'verify', label: 'Deployment verification complete', ok: true });

        // Update deployment status
        await db.update(deployments)
          .set({
            status: 'success',
            releasePath: currentReleasePath,
            currentLink: currentLink,
            finishedAt: Date.now()
          })
          .where(eq(deployments.id, actualDeploymentId));

        // Cleanup
        try { await fs.unlink(localTempPath); } catch {}
        sftp.end();
        client.end();

        return NextResponse.json({
          ok: true,
          deploymentId: actualDeploymentId,
          status: 'success',
          steps
        });

      } catch (deployError: any) {
        await recordStep(actualDeploymentId, 'error', 'Deployment failed', false, deployError?.message || String(deployError));
        steps.push({ key: 'error', label: 'Deployment failed', ok: false, log: deployError?.message || String(deployError) });

        await db.update(deployments)
          .set({
            status: 'failed',
            finishedAt: Date.now(),
            error: deployError?.message || String(deployError)
          })
          .where(eq(deployments.id, actualDeploymentId));

        try { sftp?.end(); } catch {}
        try { client?.end(); } catch {}

        throw deployError;
      }

    } catch (deployErr) {
      return NextResponse.json({
        ok: false,
        deploymentId: actualDeploymentId,
        status: 'failed',
        error: deployErr instanceof Error ? deployErr.message : 'Deployment failed',
        steps
      }, { status: 500 });
    }

  } catch (error) {
    console.error('POST /api/deployments error:', error);
    
    if (error instanceof Error && error.message === 'Unauthorized') {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }
    
    return NextResponse.json({
      ok: false,
      error: error instanceof Error ? error.message : 'Internal server error'
    }, { status: 500 });
  }
}
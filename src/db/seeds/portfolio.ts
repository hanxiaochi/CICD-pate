import { db } from '@/db';
import {
  deploymentSteps,
  deployments,
  packages,
  projects,
  systems,
  targets,
} from '@/db/schema';
import { eq } from 'drizzle-orm';

async function findOrCreateSystem(name: string, createdAt: number) {
  const existing = await db.select().from(systems).where(eq(systems.name, name)).limit(1);
  if (existing[0]) return existing[0];

  const inserted = await db.insert(systems).values({ name, createdAt }).returning();
  return inserted[0];
}

async function findOrCreateProject(
  systemId: number,
  name: string,
  repoUrl: string,
  buildCmd: string,
  createdAt: number,
) {
  const existing = await db.select().from(projects).where(eq(projects.name, name)).limit(1);
  if (existing[0]) return existing[0];

  const inserted = await db.insert(projects).values({
    systemId,
    name,
    repoUrl,
    vcsType: 'git',
    buildCmd,
    createdAt,
  }).returning();
  return inserted[0];
}

async function findOrCreatePackage(projectId: number, name: string, createdAt: number) {
  const existing = await db.select().from(packages).where(eq(packages.name, name)).limit(1);
  if (existing[0]) return existing[0];

  const inserted = await db.insert(packages).values({
    projectId,
    name,
    fileUrl: `/synthetic/packages/${name}.tgz`,
    checksum: 'synthetic-demo-checksum-not-for-release',
    size: 18_874_368,
    createdAt,
  }).returning();
  return inserted[0];
}

async function ensureDeployment(
  name: string,
  refs: { systemId: number; projectId: number; packageId: number; targetId: number },
  status: 'success' | 'failed',
  startedAt: number,
) {
  const existing = await db.select().from(deployments)
    .where(eq(deployments.releasePath, `/opt/apps/releases/${name}`))
    .limit(1);
  if (existing[0]) return existing[0];

  const inserted = await db.insert(deployments).values({
    ...refs,
    status,
    releasePath: `/opt/apps/releases/${name}`,
    currentLink: status === 'success' ? '/opt/apps/current' : null,
    startedAt,
    finishedAt: startedAt + 124_000,
    error: status === 'failed' ? 'Synthetic health-check failure for portfolio demonstration' : null,
  }).returning();

  await db.insert(deploymentSteps).values([
    {
      deploymentId: inserted[0].id,
      key: 'prepare',
      label: 'Validate package and prepare release directory',
      ok: true,
      log: 'Synthetic validation completed',
      createdAt: startedAt + 15_000,
    },
    {
      deploymentId: inserted[0].id,
      key: 'health',
      label: 'Run post-deployment health check',
      ok: status === 'success',
      log: status === 'success' ? 'Synthetic health check passed' : 'Synthetic health check failed',
      createdAt: startedAt + 110_000,
    },
  ]);

  return inserted[0];
}

export async function seedPortfolioData() {
  const targetList = await db.select().from(targets);
  if (targetList.length === 0) {
    throw new Error('Portfolio seed requires targets to be seeded first');
  }

  const commerce = await findOrCreateSystem('Commerce Platform', new Date('2026-08-01').getTime());
  const analytics = await findOrCreateSystem('Data Operations', new Date('2026-08-05').getTime());

  const orderApi = await findOrCreateProject(
    commerce.id,
    'Order API',
    'https://git.example.invalid/portfolio/order-api.git',
    'npm ci && npm test && npm run build',
    new Date('2026-08-10').getTime(),
  );
  const reporting = await findOrCreateProject(
    analytics.id,
    'Reporting Service',
    'https://git.example.invalid/portfolio/reporting-service.git',
    'bundle install && bundle exec rspec',
    new Date('2026-08-12').getTime(),
  );

  const orderPackage = await findOrCreatePackage(orderApi.id, 'order-api-2026.09.27', new Date('2026-09-27T09:00:00Z').getTime());
  const reportPackage = await findOrCreatePackage(reporting.id, 'reporting-2026.09.26', new Date('2026-09-26T08:30:00Z').getTime());

  await ensureDeployment(
    'order-api-2026.09.27',
    { systemId: commerce.id, projectId: orderApi.id, packageId: orderPackage.id, targetId: targetList[1]?.id ?? targetList[0].id },
    'success',
    new Date('2026-09-27T10:00:00Z').getTime(),
  );
  await ensureDeployment(
    'reporting-2026.09.26',
    { systemId: analytics.id, projectId: reporting.id, packageId: reportPackage.id, targetId: targetList[0].id },
    'failed',
    new Date('2026-09-26T09:15:00Z').getTime(),
  );
}

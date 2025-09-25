import { sqliteTable, integer, text } from 'drizzle-orm/sqlite-core';

export const users = sqliteTable('users', {
  id: integer('id').primaryKey({ autoIncrement: true }),
  name: text('name').notNull(),
  email: text('email').notNull().unique(),
  role: text('role').notNull().default('viewer'),
  scopes: text('scopes', { mode: 'json' }).notNull().default('[]'),
  status: text('status').notNull().default('active'),
  createdAt: integer('created_at').notNull(),
  updatedAt: integer('updated_at').notNull(),
});

export const targets = sqliteTable('targets', {
  id: integer('id').primaryKey({ autoIncrement: true }),
  name: text('name').notNull(),
  host: text('host').notNull(),
  sshUser: text('ssh_user').notNull().default('root'),
  sshPort: integer('ssh_port').notNull().default(22),
  rootPath: text('root_path').notNull().default('/opt/apps'),
  env: text('env').notNull().default('prod'), // dev, staging, prod
  authType: text('auth_type').notNull().default('password'), // password, key
  hasPassword: integer('has_password', { mode: 'boolean' }).default(false),
  hasPrivateKey: integer('has_private_key', { mode: 'boolean' }).default(false),
  passwordEncrypted: text('password_encrypted'),
  privateKeyEncrypted: text('private_key_encrypted'),
  passphraseEncrypted: text('passphrase_encrypted'),
  createdAt: integer('created_at').notNull(),
  updatedAt: integer('updated_at').notNull(),
});

export const auditLogs = sqliteTable('audit_logs', {
  id: integer('id').primaryKey({ autoIncrement: true }),
  userId: integer('user_id').references(() => users.id),
  action: text('action').notNull(),
  resource: text('resource').notNull(),
  resourceId: integer('resource_id'),
  success: integer('success').notNull(),
  details: text('details'),
  ip: text('ip'),
  userAgent: text('user_agent'),
  createdAt: integer('created_at').notNull(),
});

export const systems = sqliteTable('systems', {
  id: integer('id').primaryKey({ autoIncrement: true }),
  name: text('name').notNull(),
  createdAt: integer('created_at').notNull(),
});

export const projects = sqliteTable('projects', {
  id: integer('id').primaryKey({ autoIncrement: true }),
  systemId: integer('system_id').references(() => systems.id),
  name: text('name').notNull(),
  repoUrl: text('repo_url').notNull(),
  vcsType: text('vcs_type').notNull().default('git'), // git or svn
  buildCmd: text('build_cmd'),
  createdAt: integer('created_at').notNull(),
});

export const packages = sqliteTable('packages', {
  id: integer('id').primaryKey({ autoIncrement: true }),
  projectId: integer('project_id').references(() => projects.id),
  name: text('name').notNull(),
  fileUrl: text('file_url').notNull(),
  checksum: text('checksum').notNull(),
  size: integer('size').notNull(),
  createdAt: integer('created_at').notNull(),
});

export const deployments = sqliteTable('deployments', {
  id: integer('id').primaryKey({ autoIncrement: true }),
  systemId: integer('system_id').references(() => systems.id),
  projectId: integer('project_id').references(() => projects.id),
  packageId: integer('package_id').references(() => packages.id),
  targetId: integer('target_id').references(() => targets.id),
  status: text('status').notNull().default('pending'), // pending, success, failed
  releasePath: text('release_path'),
  currentLink: text('current_link'),
  startedAt: integer('started_at').notNull(),
  finishedAt: integer('finished_at'),
  error: text('error'),
});

export const deploymentSteps = sqliteTable('deployment_steps', {
  id: integer('id').primaryKey({ autoIncrement: true }),
  deploymentId: integer('deployment_id').references(() => deployments.id),
  key: text('key').notNull(),
  label: text('label').notNull(),
  ok: integer('ok', { mode: 'boolean' }).notNull(),
  log: text('log'),
  createdAt: integer('created_at').notNull(),
});
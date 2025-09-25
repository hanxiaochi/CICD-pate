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
  authType: text('auth_type').notNull().default('password'),
  password: text('password'),
  privateKey: text('private_key'),
  passphrase: text('passphrase'),
  env: text('env').notNull().default('prod'),
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
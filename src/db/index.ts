import { drizzle } from 'drizzle-orm/libsql';
import { createClient } from '@libsql/client';
import * as schema from '@/db/schema';

const client = createClient({
  url: process.env.DATABASE_URL?.trim() || 'file:./cicd-pate.db',
});

export const db = drizzle(client, { schema });

export type Database = typeof db;

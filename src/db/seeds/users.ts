import { db } from '@/db';
import { users } from '@/db/schema';
import { eq } from 'drizzle-orm';

export async function seedDefaultAdmin() {
    try {
        // Check if admin user already exists
        const existingAdmin = await db
            .select()
            .from(users)
            .where(eq(users.email, 'admin@example.com'))
            .limit(1);

        if (existingAdmin.length > 0) {
            console.log('ℹ️ Default admin user already exists, skipping creation');
            return;
        }

        // Create default admin user
        const now = Date.now();
        const defaultAdmin = {
            name: '管理员',
            email: 'admin@example.com',
            role: 'admin',
            scopes: ['projects', 'pipelines', 'deployments', 'control'],
            status: 'active',
            createdAt: now,
            updatedAt: now,
        };

        await db.insert(users).values(defaultAdmin);
        
        console.log('✅ Default admin user created successfully');
    } catch (error) {
        console.error('❌ Failed to create default admin user:', error);
        throw error;
    }
}

async function main() {
    await seedDefaultAdmin();
}

main().catch((error) => {
    console.error('❌ Seeder failed:', error);
});
import { db } from '@/db';
import { users } from '@/db/schema';
import { eq } from 'drizzle-orm';

export async function seedUsers() {
    const sampleUsers = [
        {
            name: 'Admin User',
            email: 'admin@example.com',
            role: 'admin',
            scopes: ['projects', 'pipelines', 'deployments', 'control'],
            status: 'active',
            createdAt: Date.now(),
            updatedAt: Date.now(),
        },
        {
            name: 'Developer User',
            email: 'developer@example.com',
            role: 'developer',
            scopes: ['projects', 'pipelines', 'deployments'],
            status: 'active',
            createdAt: Date.now(),
            updatedAt: Date.now(),
        },
        {
            name: 'Viewer User',
            email: 'viewer@example.com',
            role: 'viewer',
            scopes: ['projects'],
            status: 'active',
            createdAt: Date.now(),
            updatedAt: Date.now(),
        },
        {
            name: 'Inactive Admin',
            email: 'inactive@example.com',
            role: 'admin',
            scopes: ['projects', 'pipelines', 'deployments', 'control'],
            status: 'disabled',
            createdAt: Date.now(),
            updatedAt: Date.now(),
        }
    ];

    for (const user of sampleUsers) {
        const existingUser = await db.select().from(users).where(eq(users.email, user.email)).limit(1);
        
        if (existingUser.length > 0) {
            console.log(`ℹ️ User with email ${user.email} already exists, skipping...`);
        } else {
            await db.insert(users).values(user);
            console.log(`✅ Created user: ${user.name} (${user.email}) with role ${user.role}`);
        }
    }
    
    console.log('✅ Users seeder completed successfully');
}

// Keep backward compatibility
export async function seedDefaultAdmin() {
    await seedUsers();
}

async function main() {
    await seedUsers();
}

main().catch((error) => {
    console.error('❌ Seeder failed:', error);
});
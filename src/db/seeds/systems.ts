import { db } from '@/db';
import { systems } from '@/db/schema';

async function main() {
    const now = Date.now();
    const thirtyDaysAgo = now - (30 * 24 * 60 * 60 * 1000);
    
    const sampleSystems = [
        {
            name: 'Web Applications',
            createdAt: Math.floor(thirtyDaysAgo + (7 * 24 * 60 * 60 * 1000)),
        },
        {
            name: 'Microservices',
            createdAt: Math.floor(thirtyDaysAgo + (15 * 24 * 60 * 60 * 1000)),
        },
        {
            name: 'Legacy Systems',
            createdAt: Math.floor(thirtyDaysAgo + (22 * 24 * 60 * 60 * 1000)),
        }
    ];

    await db.insert(systems).values(sampleSystems);
    
    console.log('✅ Systems seeder completed successfully');
}

main().catch((error) => {
    console.error('❌ Seeder failed:', error);
});
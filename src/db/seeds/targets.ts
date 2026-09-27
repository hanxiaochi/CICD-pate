import { db } from '@/db';
import { targets } from '@/db/schema';
import { eq } from 'drizzle-orm';

export async function seedTargets() {
    try {
        console.log('📋 Creating sample targets...');

        const sampleTargetsData = [
            {
                name: 'Development API Server',
                host: '127.0.0.1',
                sshUser: 'devuser',
                sshPort: 2222,
                rootPath: '/home/devuser/apps',
                authType: 'password',
                hasPassword: false,
                hasPrivateKey: false,
                passwordEncrypted: null,
                privateKeyEncrypted: null,
                passphraseEncrypted: null,
                env: 'dev',
                createdAt: new Date('2024-01-15').getTime(),
                updatedAt: new Date('2024-01-15').getTime(),
            },
            {
                name: 'Staging Web Server',
                host: '127.0.0.1',
                sshUser: 'stageuser',
                sshPort: 2223,
                rootPath: '/var/www/staging',
                authType: 'key',
                hasPassword: false,
                hasPrivateKey: false,
                passwordEncrypted: null,
                privateKeyEncrypted: null,
                passphraseEncrypted: null,
                env: 'staging',
                createdAt: new Date('2024-01-20').getTime(),
                updatedAt: new Date('2024-01-20').getTime(),
            },
            {
                name: 'Production App Server',
                host: '127.0.0.1',
                sshUser: 'produser',
                sshPort: 22,
                rootPath: '/opt/production',
                authType: 'password',
                hasPassword: false,
                hasPrivateKey: false,
                passwordEncrypted: null,
                privateKeyEncrypted: null,
                passphraseEncrypted: null,
                env: 'prod',
                createdAt: new Date('2024-02-01').getTime(),
                updatedAt: new Date('2024-02-01').getTime(),
            },
            {
                name: 'Development Database Server',
                host: '127.0.0.1',
                sshUser: 'dbuser',
                sshPort: 2224,
                rootPath: '/home/dbuser/databases',
                authType: 'key',
                hasPassword: false,
                hasPrivateKey: false,
                passwordEncrypted: null,
                privateKeyEncrypted: null,
                passphraseEncrypted: null,
                env: 'dev',
                createdAt: new Date('2024-02-05').getTime(),
                updatedAt: new Date('2024-02-05').getTime(),
            },
            {
                name: 'Staging Load Balancer',
                host: '127.0.0.1',
                sshUser: 'lbuser',
                sshPort: 2225,
                rootPath: '/etc/nginx/sites',
                authType: 'password',
                hasPassword: false,
                hasPrivateKey: false,
                passwordEncrypted: null,
                privateKeyEncrypted: null,
                passphraseEncrypted: null,
                env: 'staging',
                createdAt: new Date('2024-02-10').getTime(),
                updatedAt: new Date('2024-02-10').getTime(),
            }
        ];

        let created = 0;
        for (const target of sampleTargetsData) {
            const existing = await db.select({ id: targets.id })
                .from(targets)
                .where(eq(targets.name, target.name))
                .limit(1);

            if (existing.length === 0) {
                await db.insert(targets).values(target);
                created += 1;
            }
        }
        
        console.log('✅ Targets seeder completed successfully');
        console.log(`📊 Created ${created} targets across environments: dev, staging, prod`);
        
    } catch (error) {
        console.error('❌ Failed to seed targets:', error);
        throw error;
    }
}

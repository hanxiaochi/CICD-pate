import { db } from '@/db';
import { targets } from '@/db/schema';

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
                password: null, // No credentials for demo
                privateKey: null,
                passphrase: null,
                env: 'dev',
                createdAt: Math.floor(new Date('2024-01-15').getTime() / 1000),
                updatedAt: Math.floor(new Date('2024-01-15').getTime() / 1000),
            },
            {
                name: 'Staging Web Server',
                host: '127.0.0.1',
                sshUser: 'stageuser',
                sshPort: 2223,
                rootPath: '/var/www/staging',
                authType: 'key',
                password: null,
                privateKey: null, // No credentials for demo
                passphrase: null,
                env: 'staging',
                createdAt: Math.floor(new Date('2024-01-20').getTime() / 1000),
                updatedAt: Math.floor(new Date('2024-01-20').getTime() / 1000),
            },
            {
                name: 'Production App Server',
                host: '127.0.0.1',
                sshUser: 'produser',
                sshPort: 22,
                rootPath: '/opt/production',
                authType: 'password',
                password: null, // No credentials for demo
                privateKey: null,
                passphrase: null,
                env: 'prod',
                createdAt: Math.floor(new Date('2024-02-01').getTime() / 1000),
                updatedAt: Math.floor(new Date('2024-02-01').getTime() / 1000),
            },
            {
                name: 'Development Database Server',
                host: '127.0.0.1',
                sshUser: 'dbuser',
                sshPort: 2224,
                rootPath: '/home/dbuser/databases',
                authType: 'key',
                password: null,
                privateKey: null, // No credentials for demo
                passphrase: null,
                env: 'dev',
                createdAt: Math.floor(new Date('2024-02-05').getTime() / 1000),
                updatedAt: Math.floor(new Date('2024-02-05').getTime() / 1000),
            },
            {
                name: 'Staging Load Balancer',
                host: '127.0.0.1',
                sshUser: 'lbuser',
                sshPort: 2225,
                rootPath: '/etc/nginx/sites',
                authType: 'password',
                password: null, // No credentials for demo
                privateKey: null,
                passphrase: null,
                env: 'staging',
                createdAt: Math.floor(new Date('2024-02-10').getTime() / 1000),
                updatedAt: Math.floor(new Date('2024-02-10').getTime() / 1000),
            }
        ];

        await db.insert(targets).values(sampleTargetsData);
        
        console.log('✅ Targets seeder completed successfully');
        console.log(`📊 Created ${sampleTargetsData.length} targets across environments: dev, staging, prod`);
        
    } catch (error) {
        console.error('❌ Failed to seed targets:', error);
        throw error;
    }
}

async function main() {
    await seedTargets();
}

main().catch((error) => {
    console.error('❌ Seeder failed:', error);
});
import { db } from '@/db';
import { packages } from '@/db/schema';

async function main() {
    const samplePackages = [
        {
            projectId: 1,
            name: 'auth-service-v1.0.0.jar',
            fileUrl: '/opt/builds/auth-service-v1.0.0.jar',
            checksum: 'a1b2c3d4e5f6789012345678901234567890abcdef1234567890abcdef123456',
            size: 12582912, // 12MB
            createdAt: Math.floor(new Date('2024-01-15T10:30:00Z').getTime() / 1000),
        },
        {
            projectId: 1,
            name: 'auth-service-v1.1.0.jar',
            fileUrl: '/opt/builds/auth-service-v1.1.0.jar',
            checksum: 'b2c3d4e5f6789012345678901234567890abcdef1234567890abcdef1234567',
            size: 13107200, // 12.5MB
            createdAt: Math.floor(new Date('2024-02-01T14:20:00Z').getTime() / 1000),
        },
        {
            projectId: 2,
            name: 'user-api-v2.0.0.tar.gz',
            fileUrl: '/opt/builds/user-api-v2.0.0.tar.gz',
            checksum: 'c3d4e5f6789012345678901234567890abcdef1234567890abcdef12345678',
            size: 8388608, // 8MB
            createdAt: Math.floor(new Date('2024-01-20T09:15:00Z').getTime() / 1000),
        },
        {
            projectId: 2,
            name: 'user-api-v2.1.0.tar.gz',
            fileUrl: '/opt/builds/user-api-v2.1.0.tar.gz',
            checksum: 'd4e5f6789012345678901234567890abcdef1234567890abcdef123456789',
            size: 9437184, // 9MB
            createdAt: Math.floor(new Date('2024-02-10T16:45:00Z').getTime() / 1000),
        },
        {
            projectId: 3,
            name: 'payment-gateway-v1.5.2.war',
            fileUrl: '/opt/builds/payment-gateway-v1.5.2.war',
            checksum: 'e5f6789012345678901234567890abcdef1234567890abcdef123456789a',
            size: 25165824, // 24MB
            createdAt: Math.floor(new Date('2024-01-25T11:30:00Z').getTime() / 1000),
        },
        {
            projectId: 3,
            name: 'payment-gateway-v1.5.3.war',
            fileUrl: '/opt/builds/payment-gateway-v1.5.3.war',
            checksum: 'f6789012345678901234567890abcdef1234567890abcdef123456789ab',
            size: 26214400, // 25MB
            createdAt: Math.floor(new Date('2024-02-15T13:10:00Z').getTime() / 1000),
        },
        {
            projectId: 4,
            name: 'notification-service-v3.0.1.zip',
            fileUrl: '/opt/builds/notification-service-v3.0.1.zip',
            checksum: '6789012345678901234567890abcdef1234567890abcdef123456789abc',
            size: 15728640, // 15MB
            createdAt: Math.floor(new Date('2024-01-30T08:45:00Z').getTime() / 1000),
        },
        {
            projectId: 5,
            name: 'analytics-engine-v2.2.0.jar',
            fileUrl: '/opt/builds/analytics-engine-v2.2.0.jar',
            checksum: '789012345678901234567890abcdef1234567890abcdef123456789abcd',
            size: 41943040, // 40MB
            createdAt: Math.floor(new Date('2024-02-05T12:00:00Z').getTime() / 1000),
        },
        {
            projectId: 5,
            name: 'analytics-engine-v2.2.1.jar',
            fileUrl: '/opt/builds/analytics-engine-v2.2.1.jar',
            checksum: '89012345678901234567890abcdef1234567890abcdef123456789abcde',
            size: 43253760, // 41.25MB
            createdAt: Math.floor(new Date('2024-02-20T15:30:00Z').getTime() / 1000),
        },
        {
            projectId: 6,
            name: 'web-dashboard-v1.8.0.tar.gz',
            fileUrl: '/opt/builds/web-dashboard-v1.8.0.tar.gz',
            checksum: '9012345678901234567890abcdef1234567890abcdef123456789abcdef',
            size: 52428800, // 50MB
            createdAt: Math.floor(new Date('2024-02-12T10:15:00Z').getTime() / 1000),
        }
    ];

    await db.insert(packages).values(samplePackages);
    
    console.log('✅ Packages seeder completed successfully');
}

main().catch((error) => {
    console.error('❌ Seeder failed:', error);
});
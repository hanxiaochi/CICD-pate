import { db } from '@/db';
import { projects } from '@/db/schema';

async function main() {
    const sampleProjects = [
        {
            systemId: 1,
            name: 'E-commerce API',
            repoUrl: 'https://github.com/company/ecommerce-api.git',
            vcsType: 'git',
            buildCmd: 'mvn clean package',
            createdAt: Math.floor(new Date('2024-01-15T10:30:00Z').getTime() / 1000),
        },
        {
            systemId: 1,
            name: 'Admin Dashboard',
            repoUrl: 'https://github.com/company/admin-dashboard.git',
            vcsType: 'git',
            buildCmd: 'npm run build',
            createdAt: Math.floor(new Date('2024-01-20T14:15:00Z').getTime() / 1000),
        },
        {
            systemId: 2,
            name: 'User Service',
            repoUrl: 'https://github.com/company/user-service.git',
            vcsType: 'git',
            buildCmd: 'gradle build',
            createdAt: Math.floor(new Date('2024-02-01T09:45:00Z').getTime() / 1000),
        },
        {
            systemId: 2,
            name: 'Payment Service',
            repoUrl: 'https://github.com/company/payment-service.git',
            vcsType: 'git',
            buildCmd: 'mvn clean package -P production',
            createdAt: Math.floor(new Date('2024-02-10T11:20:00Z').getTime() / 1000),
        },
        {
            systemId: 3,
            name: 'ERP System',
            repoUrl: 'https://github.com/enterprise/erp-system.git',
            vcsType: 'git',
            buildCmd: 'npm run build:prod',
            createdAt: Math.floor(new Date('2024-02-15T16:30:00Z').getTime() / 1000),
        },
        {
            systemId: 3,
            name: 'CRM System',
            repoUrl: 'https://github.com/enterprise/crm-system.git',
            vcsType: 'git',
            buildCmd: 'gradle clean build',
            createdAt: Math.floor(new Date('2024-02-25T13:00:00Z').getTime() / 1000),
        }
    ];

    await db.insert(projects).values(sampleProjects);
    
    console.log('✅ Projects seeder completed successfully');
}

main().catch((error) => {
    console.error('❌ Seeder failed:', error);
});
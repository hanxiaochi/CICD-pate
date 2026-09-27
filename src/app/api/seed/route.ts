import { NextRequest, NextResponse } from 'next/server';
import { requireApiToken } from '@/lib/api-auth';

async function seedUsers() {
    const { seedUsers } = await import('@/db/seeds/users');
    await seedUsers();
}

async function seedTargets() {
    const { seedTargets } = await import('@/db/seeds/targets');
    await seedTargets();
}

export async function POST(request: NextRequest) {
  try {
    requireApiToken(request);
    console.log('Starting database seeding operation...');
    
    await seedUsers();
    await seedTargets();
    
    console.log('Database seeding completed successfully');
    
    return NextResponse.json({
      success: true,
      message: 'Database seeded successfully with users and targets'
    }, { status: 200 });
    
  } catch (error) {
    console.error('Database seeding failed:', error);
    if (error instanceof Error && error.message === 'Unauthorized') {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }
    
    return NextResponse.json({
      success: false,
      error: 'Failed to seed database'
    }, { status: 500 });
  }
}

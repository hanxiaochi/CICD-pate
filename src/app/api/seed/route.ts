import { NextRequest, NextResponse } from 'next/server';
import { seedDefaultAdmin } from '@/db/seeds/users';

export async function POST(request: NextRequest) {
  try {
    console.log('Starting database seeding operation...');
    
    await seedDefaultAdmin();
    
    console.log('Database seeding completed successfully');
    
    return NextResponse.json({
      success: true,
      message: 'Default admin user seeded successfully'
    }, { status: 200 });
    
  } catch (error) {
    console.error('Database seeding failed:', error);
    
    return NextResponse.json({
      success: false,
      error: 'Failed to seed database: ' + (error instanceof Error ? error.message : 'Unknown error')
    }, { status: 500 });
  }
}
import { NextRequest, NextResponse } from 'next/server';
import { db } from '@/db';
import { systems } from '@/db/schema';
import { eq, desc } from 'drizzle-orm';

function requireAuth(request: NextRequest) {
  const auth = request.headers.get('authorization');
  if (!auth || !auth.startsWith('Bearer ') || !auth.slice(7).trim()) {
    throw new Error('Unauthorized');
  }
}

export async function GET(request: NextRequest) {
  try {
    requireAuth(request);

    const systemsList = await db.select()
      .from(systems)
      .orderBy(desc(systems.createdAt));

    return NextResponse.json(systemsList);
  } catch (error) {
    console.error('GET /api/systems error:', error);
    
    if (error instanceof Error && error.message === 'Unauthorized') {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }
    
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
  }
}

export async function POST(request: NextRequest) {
  try {
    requireAuth(request);

    const body = await request.json();
    const { name } = body;

    if (!name || typeof name !== 'string' || !name.trim()) {
      return NextResponse.json({
        error: 'Name is required and must be a non-empty string'
      }, { status: 400 });
    }

    const newSystem = await db.insert(systems)
      .values({
        name: name.trim(),
        createdAt: Date.now()
      })
      .returning();

    return NextResponse.json(newSystem[0], { status: 201 });
  } catch (error) {
    console.error('POST /api/systems error:', error);
    
    if (error instanceof Error && error.message === 'Unauthorized') {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }
    
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
  }
}
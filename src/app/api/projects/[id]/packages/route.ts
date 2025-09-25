import { NextRequest, NextResponse } from 'next/server';
import { db } from '@/db';
import { packages, projects } from '@/db/schema';
import { eq, desc } from 'drizzle-orm';

function requireAuth(request: NextRequest) {
  const auth = request.headers.get('authorization');
  if (!auth || !auth.startsWith('Bearer ') || !auth.slice(7).trim()) {
    throw new Error('Unauthorized');
  }
}

export async function GET(
  request: NextRequest,
  { params }: { params: { id: string } }
) {
  try {
    requireAuth(request);

    const { id } = params;

    if (!id || isNaN(parseInt(id))) {
      return NextResponse.json({
        error: 'Valid project ID is required'
      }, { status: 400 });
    }

    const projectId = parseInt(id);

    // Check if project exists
    const project = await db.select()
      .from(projects)
      .where(eq(projects.id, projectId))
      .limit(1);

    if (project.length === 0) {
      return NextResponse.json({
        error: 'Project not found'
      }, { status: 404 });
    }

    // Get packages for the project
    const packagesList = await db.select()
      .from(packages)
      .where(eq(packages.projectId, projectId))
      .orderBy(desc(packages.createdAt));

    return NextResponse.json(packagesList);
  } catch (error) {
    console.error('GET /api/projects/[id]/packages error:', error);
    
    if (error instanceof Error && error.message === 'Unauthorized') {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }
    
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
  }
}

export async function POST(
  request: NextRequest,
  { params }: { params: { id: string } }
) {
  try {
    requireAuth(request);

    const { id } = params;

    if (!id || isNaN(parseInt(id))) {
      return NextResponse.json({
        error: 'Valid project ID is required'
      }, { status: 400 });
    }

    const projectId = parseInt(id);

    // Check if project exists
    const project = await db.select()
      .from(projects)
      .where(eq(projects.id, projectId))
      .limit(1);

    if (project.length === 0) {
      return NextResponse.json({
        error: 'Project not found'
      }, { status: 404 });
    }

    const body = await request.json();
    const { name, fileUrl, checksum, size } = body;

    // Validate required fields
    if (!name || typeof name !== 'string' || !name.trim()) {
      return NextResponse.json({
        error: 'Package name is required'
      }, { status: 400 });
    }

    if (!fileUrl || typeof fileUrl !== 'string' || !fileUrl.trim()) {
      return NextResponse.json({
        error: 'File URL is required'
      }, { status: 400 });
    }

    if (!checksum || typeof checksum !== 'string' || !checksum.trim()) {
      return NextResponse.json({
        error: 'Checksum is required'
      }, { status: 400 });
    }

    if (!size || typeof size !== 'number' || size <= 0) {
      return NextResponse.json({
        error: 'Valid file size is required'
      }, { status: 400 });
    }

    const newPackage = await db.insert(packages)
      .values({
        projectId,
        name: name.trim(),
        fileUrl: fileUrl.trim(),
        checksum: checksum.trim(),
        size,
        createdAt: Date.now()
      })
      .returning();

    return NextResponse.json(newPackage[0], { status: 201 });
  } catch (error) {
    console.error('POST /api/projects/[id]/packages error:', error);
    
    if (error instanceof Error && error.message === 'Unauthorized') {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }
    
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
  }
}
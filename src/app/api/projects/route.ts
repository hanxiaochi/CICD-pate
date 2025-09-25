import { NextRequest, NextResponse } from 'next/server';
import { db } from '@/db';
import { projects, systems } from '@/db/schema';
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

    const projectsList = await db.select({
      id: projects.id,
      systemId: projects.systemId,
      name: projects.name,
      repoUrl: projects.repoUrl,
      vcsType: projects.vcsType,
      buildCmd: projects.buildCmd,
      createdAt: projects.createdAt,
      systemName: systems.name
    })
      .from(projects)
      .leftJoin(systems, eq(projects.systemId, systems.id))
      .orderBy(desc(projects.createdAt));

    return NextResponse.json(projectsList);
  } catch (error) {
    console.error('GET /api/projects error:', error);
    
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
    const { name, systemId, repoUrl, vcsType = 'git', buildCmd } = body;

    if (!name || typeof name !== 'string' || !name.trim()) {
      return NextResponse.json({
        error: 'Name is required and must be a non-empty string'
      }, { status: 400 });
    }

    if (!repoUrl || typeof repoUrl !== 'string' || !repoUrl.trim()) {
      return NextResponse.json({
        error: 'Repository URL is required'
      }, { status: 400 });
    }

    // Validate systemId if provided
    if (systemId !== null && systemId !== undefined) {
      if (typeof systemId !== 'number') {
        return NextResponse.json({
          error: 'System ID must be a number'
        }, { status: 400 });
      }

      const systemExists = await db.select()
        .from(systems)
        .where(eq(systems.id, systemId))
        .limit(1);

      if (systemExists.length === 0) {
        return NextResponse.json({
          error: 'System not found'
        }, { status: 404 });
      }
    }

    const newProject = await db.insert(projects)
      .values({
        name: name.trim(),
        systemId: systemId || null,
        repoUrl: repoUrl.trim(),
        vcsType: vcsType || 'git',
        buildCmd: buildCmd?.trim() || null,
        createdAt: Date.now()
      })
      .returning();

    return NextResponse.json(newProject[0], { status: 201 });
  } catch (error) {
    console.error('POST /api/projects error:', error);
    
    if (error instanceof Error && error.message === 'Unauthorized') {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }
    
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
  }
}
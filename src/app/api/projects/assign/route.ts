import { NextResponse } from "next/server";

// Use same in-memory store as other routes
const g = globalThis as any;
if (!g.__PROJECTS__) {
  g.__PROJECTS__ = [];
  g.__PROJECT_ID__ = 1;
}
if (!g.__SYSTEMS__) {
  g.__SYSTEMS__ = [{ id: 1, name: "默认系统", created_at: Date.now() }];
  g.__SYSTEM_ID__ = 2;
}

export async function POST(req: Request) {
  const body = await req.json().catch(() => ({}));
  const { project_id, system_id } = body || {};
  if (typeof project_id !== "number") {
    return NextResponse.json({ error: "缺少或非法的 project_id" }, { status: 400 });
  }
  if (system_id !== null && typeof system_id !== "number") {
    return NextResponse.json({ error: "缺少或非法的 system_id" }, { status: 400 });
  }

  const proj = g.__PROJECTS__.find((p: any) => p.id === project_id);
  if (!proj) return NextResponse.json({ error: "项目不存在" }, { status: 404 });

  // Allow unassign with null
  if (system_id === null) {
    proj.system_id = null;
  } else {
    const sys = g.__SYSTEMS__.find((s: any) => s.id === system_id);
    if (!sys) return NextResponse.json({ error: "系统不存在" }, { status: 404 });
    proj.system_id = system_id;
  }

  return NextResponse.json({ ok: true, project: proj });
}
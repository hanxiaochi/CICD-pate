import { NextResponse } from "next/server";

// In-memory mock storage
const g = globalThis as any;
if (!g.__PROJECTS__) {
  g.__PROJECTS__ = [
    {
      id: 1,
      name: "demo",
      repo_type: "git",
      repo_url: "https://github.com/acme/demo.git",
      branch: "main",
      created_at: Date.now(),
    },
  ];
  g.__PROJECT_ID__ = 2;
}

export async function GET() {
  return NextResponse.json(g.__PROJECTS__);
}

export async function POST(req: Request) {
  const body = await req.json().catch(() => ({}));
  const { name, repo_type, repo_url, branch, credentials_json, pipeline } = body || {};
  if (!name || !repo_type || !repo_url) {
    return NextResponse.json({ error: "Missing fields" }, { status: 400 });
  }
  const id = g.__PROJECT_ID__++;
  const item = {
    id,
    name,
    repo_type,
    repo_url,
    branch: branch || "main",
    credentials_json: credentials_json || null,
    pipeline: pipeline || "",
    created_at: Date.now(),
  };
  g.__PROJECTS__.push(item);
  return NextResponse.json(item, { status: 201 });
}
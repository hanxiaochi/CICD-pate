import { NextResponse } from "next/server";

export async function POST(req: Request) {
  const body = await req.json().catch(() => ({}));
  const { repo_url } = body || {};
  if (!repo_url) {
    return NextResponse.json({ ok: false, error: "Missing repo_url" }, { status: 400 });
  }
  // Mock: always succeed with echo details
  return NextResponse.json({ ok: true, details: `Checked ${repo_url}` });
}
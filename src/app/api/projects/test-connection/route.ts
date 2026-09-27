import { NextResponse } from "next/server";
import { hasValidApiToken } from "@/lib/api-auth";

export async function POST(req: Request) {
  if (!hasValidApiToken(req)) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }
  const body = await req.json().catch(() => ({}));
  const { repo_url } = body || {};
  if (!repo_url) {
    return NextResponse.json({ ok: false, error: "Missing repo_url" }, { status: 400 });
  }
  // Mock: always succeed with echo details
  return NextResponse.json({ ok: true, details: `Checked ${repo_url}` });
}

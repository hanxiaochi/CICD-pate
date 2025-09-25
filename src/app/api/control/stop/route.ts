import { NextResponse } from "next/server";

const g = globalThis as any;
if (!g.__PROCESSES__) g.__PROCESSES__ = [] as any[];

export async function POST(req: Request) {
  const body = await req.json().catch(() => ({}));
  const { pid } = body || {};
  if (!pid) return NextResponse.json({ error: "Missing pid" }, { status: 400 });

  const idx = g.__PROCESSES__.findIndex((p: any) => p.pid === Number(pid));
  if (idx >= 0) {
    g.__PROCESSES__[idx].status = "stopped";
  }
  return NextResponse.json({ ok: true });
}
import { NextResponse } from "next/server";

const g = globalThis as any;
if (!g.__PROCESSES__) g.__PROCESSES__ = [] as any[];

export async function POST(req: Request) {
  const body = await req.json().catch(() => ({}));
  const { target_id, workdir, jar_path, java_opts, env } = body || {};

  if (!workdir || !jar_path) {
    return NextResponse.json({ error: "Missing workdir or jar_path" }, { status: 400 });
  }

  const pid = Math.floor(20000 + Math.random() * 5000);
  const record = {
    pid,
    target_id: Number(target_id) || 1,
    workdir,
    jar_path,
    java_opts: java_opts || "",
    env: env || {},
    status: "running" as const,
    log_file: `${workdir.replace(/\/$/, "")}/app.out`,
    started_at: Date.now(),
  };
  g.__PROCESSES__.push(record);

  return NextResponse.json({ pid, status: "running", log_file: record.log_file });
}
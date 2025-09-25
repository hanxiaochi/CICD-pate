import { NextResponse } from "next/server";

const g = globalThis as any;
if (!g.__PROCESSES__) g.__PROCESSES__ = [] as any[];

export async function POST(req: Request) {
  const body = await req.json().catch(() => ({}));
  const {
    mode = "nohup",
    target_id,
    workdir,
    jar_path,
    java_opts,
    env,
    start_script,
    log_file,
  } = body || {};

  // 校验参数（根据模式）
  if (mode === "sh") {
    if (!workdir || !start_script) {
      return NextResponse.json({ error: "Missing workdir or start_script" }, { status: 400 });
    }
  } else {
    if (!workdir || !jar_path) {
      return NextResponse.json({ error: "Missing workdir or jar_path" }, { status: 400 });
    }
  }

  const pid = Math.floor(20000 + Math.random() * 5000);
  const base = {
    pid,
    target_id: Number(target_id) || 1,
    workdir,
    env: env || {},
    status: "running" as const,
    started_at: Date.now(),
  } as any;

  if (mode === "sh") {
    base.mode = "sh";
    base.start_script = start_script;
    base.log_file = log_file || `${String(workdir).replace(/\/$/, "")}/app.out`;
  } else {
    base.mode = "nohup";
    base.jar_path = jar_path;
    base.java_opts = java_opts || "";
    base.log_file = log_file || `${String(workdir).replace(/\/$/, "")}/app.out`;
  }

  g.__PROCESSES__.push(base);

  return NextResponse.json({ pid, status: "running", log_file: base.log_file });
}
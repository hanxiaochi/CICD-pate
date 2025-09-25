import { NextResponse } from "next/server";

const g = globalThis as any;
if (!g.__PROCESSES__) g.__PROCESSES__ = [] as any[];

export async function POST(req: Request) {
  const body = await req.json().catch(() => ({}));
  const { pid, mode = "nohup", workdir, stop_script } = body || {};

  // 支持两种模式：
  // - nohup：必须提供 pid
  // - sh：允许通过 pid 或 (workdir + stop_script) 来定位并停止
  if (mode === "nohup") {
    if (!pid) return NextResponse.json({ error: "Missing pid" }, { status: 400 });
    const idx = g.__PROCESSES__.findIndex((p: any) => p.pid === Number(pid));
    if (idx >= 0) g.__PROCESSES__[idx].status = "stopped";
    return NextResponse.json({ ok: true });
  }

  // sh 脚本模式
  // 优先按 pid 停止；否则按 workdir + stop_script 匹配最近一条运行中的记录
  if (pid) {
    const idx = g.__PROCESSES__.findIndex((p: any) => p.pid === Number(pid));
    if (idx >= 0) g.__PROCESSES__[idx].status = "stopped";
    return NextResponse.json({ ok: true });
  }

  if (!workdir || !stop_script) {
    return NextResponse.json({ error: "Missing workdir or stop_script" }, { status: 400 });
  }

  const idx = g.__PROCESSES__
    .slice()
    .reverse()
    .findIndex((p: any) => p.mode === "sh" && p.workdir === workdir && p.status === "running");

  if (idx >= 0) {
    // 因为上面 reverse() 了，需要换算原索引
    const realIndex = g.__PROCESSES__.length - 1 - idx;
    g.__PROCESSES__[realIndex].status = "stopped";
  }

  return NextResponse.json({ ok: true });
}
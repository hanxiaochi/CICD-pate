import { NextResponse } from "next/server";
import net from "net";

export const runtime = "nodejs"; // ensure Node runtime for net module

function checkTcp({ host, port, timeout = 3000 }: { host: string; port: number; timeout?: number }) {
  return new Promise<{ ok: boolean; latencyMs?: number; error?: string }>((resolve) => {
    const start = Date.now();
    const socket = new net.Socket();

    const onDone = (ok: boolean, error?: string) => {
      try {
        socket.destroy();
      } catch {}
      const latencyMs = Date.now() - start;
      resolve(ok ? { ok: true, latencyMs } : { ok: false, error });
    };

    socket.setTimeout(timeout);
    socket.once("connect", () => onDone(true));
    socket.once("timeout", () => onDone(false, "timeout"));
    socket.once("error", (err) => onDone(false, err?.message || "error"));

    try {
      socket.connect(port, host);
    } catch (e: any) {
      onDone(false, e?.message || "connect error");
    }
  });
}

export async function POST(req: Request) {
  try {
    const body = await req.json();
    const host = String(body?.host || "").trim();
    const port = Number(body?.port ?? body?.ssh_port ?? 22);
    const timeout = Math.min(Math.max(Number(body?.timeout ?? 3000), 1000), 10000);

    if (!host) {
      return NextResponse.json({ ok: false, error: "host 为必填项" }, { status: 400 });
    }
    if (!Number.isFinite(port) || port <= 0) {
      return NextResponse.json({ ok: false, error: "port 非法" }, { status: 400 });
    }

    const result = await checkTcp({ host, port, timeout });
    const status = result.ok ? 200 : 502;
    return NextResponse.json(result, { status });
  } catch (e: any) {
    return NextResponse.json({ ok: false, error: e?.message || "Invalid JSON" }, { status: 400 });
  }
}
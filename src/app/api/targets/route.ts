import { NextResponse } from "next/server";

const g = globalThis as any;
if (!g.__TARGETS__) {
  g.__TARGETS__ = [
    { id: 1, name: "默认服务器", host: "127.0.0.1", ssh_user: "root", ssh_port: 22, root_path: "/opt/apps" },
  ];
}

export async function GET() {
  return NextResponse.json(g.__TARGETS__);
}
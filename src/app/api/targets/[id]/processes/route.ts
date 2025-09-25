import { NextResponse } from "next/server";

export async function GET(req: Request) {
  const list = [
    { pid: 23124, cmd: "java -jar app-a.jar", port: 8080, status: "running", started_at: Date.now() - 3600_000 },
    { pid: 24567, cmd: "node server.js", port: 3000, status: "running", started_at: Date.now() - 5400_000 },
  ];
  return NextResponse.json(list);
}
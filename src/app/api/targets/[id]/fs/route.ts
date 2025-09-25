import { NextResponse } from "next/server";

export async function GET(req: Request, { params }: { params: { id: string } }) {
  const { searchParams } = new URL(req.url);
  const path = searchParams.get("path") || "/opt/apps";

  // Mocked directory listing
  const now = Date.now();
  const entries = [
    { name: "app-a", type: "dir", size: 0, mtime: now - 3600_000 },
    { name: "app-b", type: "dir", size: 0, mtime: now - 7200_000 },
    { name: "dist.tar.gz", type: "file", size: 1024 * 1024 * 5, mtime: now - 86_400_000 },
  ];

  return NextResponse.json({ path, entries });
}
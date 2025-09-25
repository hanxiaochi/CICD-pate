import { NextResponse } from "next/server";

export async function POST(req: Request) {
  const body = await req.json().catch(() => ({}));
  const { email, password } = body || {};

  // Default admin account
  const isAdminUser = (email === "admin" || email === "admin@example.com") && password === "admin123";
  if (isAdminUser) {
    return NextResponse.json({
      token: "admin-token-123",
      user: { id: 1, name: "管理员", role: "admin", email: email || "admin" },
    });
  }

  return NextResponse.json({ error: "Invalid credentials" }, { status: 401 });
}
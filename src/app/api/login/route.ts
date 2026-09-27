import { NextResponse } from "next/server";
import { credentialsMatch } from "@/lib/api-auth";

export async function POST(req: Request) {
  const body = await req.json().catch(() => ({}));
  const { email, password } = body || {};

  const apiToken = process.env.CICD_API_TOKEN?.trim();
  if (
    typeof email !== "string" ||
    typeof password !== "string" ||
    !apiToken ||
    !credentialsMatch(email, password)
  ) {
    return NextResponse.json({ error: "Invalid credentials" }, { status: 401 });
  }

  if (apiToken) {
    return NextResponse.json({
      token: apiToken,
      user: { id: 1, name: "管理员", role: "admin", email },
    });
  }

  return NextResponse.json({ error: "Invalid credentials" }, { status: 401 });
}

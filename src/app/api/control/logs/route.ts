import { NextRequest } from "next/server";

export const dynamic = "force-dynamic";

export async function GET(req: NextRequest) {
  const { searchParams } = new URL(req.url);
  const path = searchParams.get("path") || "/var/log/app.log";

  // Optional bearer check (mock): allow if absent to keep demo smooth
  // const auth = req.headers.get("authorization");
  // if (!auth?.startsWith("Bearer ")) {
  //   return new Response(JSON.stringify({ error: "Unauthorized" }), { status: 401 });
  // }

  const encoder = new TextEncoder();

  const stream = new ReadableStream<Uint8Array>({
    start(controller) {
      let i = 0;
      const startTime = Date.now();

      const interval = setInterval(() => {
        i++;
        const line = `[${new Date().toISOString()}] tail -f ${path} -> line ${i} lorem ipsum dolor sit amet\n`;
        controller.enqueue(encoder.encode(line));
      }, 700);

      const timeout = setTimeout(() => {
        controller.enqueue(encoder.encode(`--- mock log stream active for ${(Date.now() - startTime) / 1000}s ---\n`));
      }, 1_000);

      // Close stream after 2 minutes to avoid leaks (demo)
      const autoClose = setTimeout(() => {
        clearInterval(interval);
        controller.enqueue(encoder.encode("[stream closed]\n"));
        controller.close();
      }, 120_000);

      const abort = () => {
        clearInterval(interval);
        clearTimeout(timeout);
        clearTimeout(autoClose);
        try {
          controller.close();
        } catch {}
      };

      // Handle client abort
      // @ts-ignore - request signal available in Next runtime
      req.signal?.addEventListener("abort", abort);
    },
  });

  return new Response(stream, {
    headers: {
      "Content-Type": "text/plain; charset=utf-8",
      "Cache-Control": "no-store",
    },
  });
}
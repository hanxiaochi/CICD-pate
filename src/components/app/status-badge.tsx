"use client";

import { useEffect, useState } from "react";
import { Badge } from "@/components/ui/badge";

export const StatusBadge = () => {
  const [status, setStatus] = useState<"checking" | "ok" | "demo">("checking");

  useEffect(() => {
    let cancelled = false;
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), 6000);

    const check = async () => {
      try {
        const token = typeof window !== "undefined" ? localStorage.getItem("bearer_token") : null;
        const res = await fetch("/api/projects", {
          method: "GET",
          headers: token ? { Authorization: `Bearer ${token}` } : undefined,
          signal: controller.signal,
          cache: "no-store",
        });
        if (!cancelled && res.ok) {
          setStatus("ok");
        } else if (!cancelled) {
          setStatus("demo");
        }
      } catch (_) {
        if (!cancelled) setStatus("demo");
      } finally {
        clearTimeout(timer);
      }
    };

    check();
    return () => {
      cancelled = true;
      controller.abort();
      clearTimeout(timer);
    };
  }, []);

  if (status === "checking") {
    return (
      <Badge variant="secondary" className="animate-pulse">状态检查中…</Badge>
    );
  }

  if (status === "ok") {
    return (
      <Badge className="bg-green-600 text-white hover:bg-green-600/90">已连接 · 可用</Badge>
    );
  }

  return (
    <Badge className="bg-amber-500 text-white hover:bg-amber-500/90" variant="secondary">演示模式</Badge>
  );
};
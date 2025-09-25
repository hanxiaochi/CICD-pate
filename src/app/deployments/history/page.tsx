"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { toast } from "sonner";
import { apiUrl, withAuth } from "@/lib/api";

type Step = { key: string; label: string; ok: boolean };

type DeploymentItem = {
  id: number;
  systemId: number | null;
  projectId: number;
  packageId: number;
  targetId: number;
  steps: Step[];
  startedAt: number;
  status: "success" | "failed" | "rolledback";
  message: string;
};

export default function DeploymentHistoryPage() {
  const [items, setItems] = useState<DeploymentItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [expands, setExpands] = useState<Record<number, boolean>>({});
  const [actingId, setActingId] = useState<number | null>(null);

  const load = async () => {
    setLoading(true);
    try {
      const res = await fetch(apiUrl("/api/deployments"), withAuth());
      const j = await res.json();
      if (!res.ok) throw new Error(j?.error || "加载失败");
      setItems(Array.isArray(j.items) ? j.items : []);
    } catch (e: any) {
      toast.error(e?.message || "加载失败");
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    load();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const rollback = async (id: number) => {
    setActingId(id);
    try {
      const res = await fetch(apiUrl(`/api/deployments/${id}/rollback`), { ...withAuth(), method: "POST" });
      const j = await res.json();
      if (!res.ok || !j?.ok) throw new Error(j?.error || "回滚失败");
      toast.success(`回滚成功（ID: ${id}）`);
      await load();
    } catch (e: any) {
      toast.error(e?.message || "回滚失败");
    } finally {
      setActingId(null);
    }
  };

  return (
    <div className="mx-auto max-w-6xl px-6 py-10 space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-semibold">发布历史</h1>
        <div className="flex items-center gap-2">
          <Link href="/deployments" className="text-sm text-muted-foreground hover:underline">返回部署</Link>
          <Button variant="outline" size="sm" onClick={load} disabled={loading}>{loading ? "刷新中…" : "刷新"}</Button>
        </div>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>历史记录</CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="overflow-x-auto">
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>ID</TableHead>
                  <TableHead>系统</TableHead>
                  <TableHead>项目</TableHead>
                  <TableHead>成品包</TableHead>
                  <TableHead>目标机</TableHead>
                  <TableHead>开始时间</TableHead>
                  <TableHead>状态</TableHead>
                  <TableHead className="text-right">操作</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {items.map((it) => {
                  const canRollback = it.status !== "rolledback";
                  return (
                    <>
                      <TableRow key={it.id}>
                        <TableCell className="font-medium">#{it.id}</TableCell>
                        <TableCell>{it.systemId ?? "-"}</TableCell>
                        <TableCell>{it.projectId}</TableCell>
                        <TableCell>{it.packageId}</TableCell>
                        <TableCell>{it.targetId}</TableCell>
                        <TableCell>{new Date(it.startedAt).toLocaleString()}</TableCell>
                        <TableCell>
                          <span className={`inline-flex items-center rounded px-2 py-0.5 text-xs ${
                            it.status === "success"
                              ? "bg-emerald-100 text-emerald-700 dark:bg-emerald-900/30 dark:text-emerald-300"
                              : it.status === "rolledback"
                              ? "bg-amber-100 text-amber-700 dark:bg-amber-900/30 dark:text-amber-300"
                              : "bg-destructive/10 text-destructive"
                          }`}>
                            {it.status === "success" ? "成功" : it.status === "rolledback" ? "已回滚" : "失败"}
                          </span>
                        </TableCell>
                        <TableCell className="text-right space-x-2">
                          <Button variant="ghost" size="sm" onClick={() => setExpands((s) => ({ ...s, [it.id]: !s[it.id] }))}>
                            {expands[it.id] ? "收起" : "步骤"}
                          </Button>
                          <Link href={`/deployments/${it.id}`} className="text-sm text-primary hover:underline align-middle">详情</Link>
                          <Button size="sm" disabled={!canRollback || actingId === it.id} onClick={() => rollback(it.id)}>
                            {actingId === it.id ? "回滚中…" : "回滚"}
                          </Button>
                        </TableCell>
                      </TableRow>
                      {expands[it.id] && (
                        <TableRow key={`steps-${it.id}`}>
                          <TableCell colSpan={8}>
                            <ul className="space-y-2">
                              {it.steps.map((s) => (
                                <li key={s.key} className="flex items-center gap-2">
                                  <span className={`h-2 w-2 rounded-full ${s.ok ? "bg-emerald-500" : "bg-destructive"}`} />
                                  <span className="text-sm">{s.label}</span>
                                  <span className={`ml-auto text-xs ${s.ok ? "text-emerald-600" : "text-destructive"}`}>{s.ok ? "OK" : "FAILED"}</span>
                                </li>
                              ))}
                            </ul>
                          </TableCell>
                        </TableRow>
                      )}
                    </>
                  );
                })}
                {items.length === 0 && !loading && (
                  <TableRow>
                    <TableCell colSpan={8} className="text-center text-sm text-muted-foreground">暂无历史记录</TableCell>
                  </TableRow>
                )}
              </TableBody>
            </Table>
          </div>
          <p className="text-xs text-muted-foreground">说明：演示环境为内存存储，刷新页面或重启将清空历史。真实项目请接入数据库存储。</p>
        </CardContent>
      </Card>
    </div>
  );
}
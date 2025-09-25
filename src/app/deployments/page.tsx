"use client";

import { useEffect, useState } from "react";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { toast } from "sonner";
import { apiUrl, withAuth } from "@/lib/api";

export default function DeploymentsPage() {
  const [root, setRoot] = useState("/opt/apps");
  const [targets, setTargets] = useState<any[]>([]);
  const [targetId, setTargetId] = useState<string>("1");
  const [loadingTargets, setLoadingTargets] = useState(false);
  const [loadingFs, setLoadingFs] = useState(false);
  const [loadingProcs, setLoadingProcs] = useState(false);
  const [directories, setDirectories] = useState<{ name: string; type: string; updatedAt?: string }[]>([]);
  const [processes, setProcesses] = useState<{ pid: number; name: string; port?: number; started?: string }[]>([]);

  // load targets on mount
  useEffect(() => {
    const loadTargets = async () => {
      setLoadingTargets(true);
      try {
        const res = await fetch(apiUrl("/api/targets"), withAuth());
        const data = await res.json();
        if (Array.isArray(data)) {
          setTargets(data);
          if (data.length > 0) setTargetId(String(data[0].id));
        }
      } catch (e) {
        toast.error("加载目标服务器失败");
      } finally {
        setLoadingTargets(false);
      }
    };
    loadTargets();
  }, []);

  async function refreshFs() {
    if (!targetId) return;
    setLoadingFs(true);
    try {
      const res = await fetch(apiUrl(`/api/targets/${targetId}/fs?path=${encodeURIComponent(root)}`), withAuth());
      const j = await res.json();
      if (!res.ok) throw new Error(j?.error || "读取目录失败");
      const list = (j.entries || []).map((it: any) => ({
        name: it.name,
        type: it.type,
        updatedAt: it.mtime ? new Date(it.mtime).toLocaleString() : undefined,
      }));
      setDirectories(list);
      toast.success("目录已刷新");
    } catch (e: any) {
      toast.error(e?.message || "读取目录失败");
    } finally {
      setLoadingFs(false);
    }
  }

  async function refreshProcs() {
    if (!targetId) return;
    setLoadingProcs(true);
    try {
      const res = await fetch(apiUrl(`/api/targets/${targetId}/processes`), withAuth());
      const j = await res.json();
      if (!res.ok) throw new Error(j?.error || "读取进程失败");
      const list = (j || []).map((p: any) => ({
        pid: p.pid,
        name: p.cmd,
        port: p.port,
        started: p.started_at ? new Date(p.started_at).toLocaleTimeString() : undefined,
      }));
      setProcesses(list);
      toast.success("进程已刷新");
    } catch (e: any) {
      toast.error(e?.message || "读取进程失败");
    } finally {
      setLoadingProcs(false);
    }
  }

  return (
    <div className="mx-auto max-w-6xl px-6 py-10 space-y-8">
      <h1 className="text-2xl font-semibold">部署与服务器监控</h1>

      <Card>
        <CardHeader>
          <CardTitle>服务器目录浏览</CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="grid gap-3 sm:grid-cols-[1fr_auto_auto] items-end">
            <div className="space-y-2">
              <Label htmlFor="target">目标服务器</Label>
              <Select value={targetId} onValueChange={setTargetId} disabled={loadingTargets}>
                <SelectTrigger id="target">
                  <SelectValue placeholder="选择服务器" />
                </SelectTrigger>
                <SelectContent>
                  {targets.map((t) => (
                    <SelectItem key={t.id} value={String(t.id)}>
                      {t.name} ({t.host})
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
            <div className="space-y-2">
              <Label htmlFor="root">根目录路径</Label>
              <Input id="root" value={root} onChange={(e) => setRoot(e.target.value)} />
            </div>
            <Button className="h-10" onClick={refreshFs} disabled={loadingFs || !targetId}>
              {loadingFs ? "刷新中..." : "刷新"}
            </Button>
          </div>

          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>名称</TableHead>
                <TableHead>类型</TableHead>
                <TableHead>更新时间</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {directories.map((d) => (
                <TableRow key={d.name}>
                  <TableCell className="font-medium">{d.name}</TableCell>
                  <TableCell>{d.type === "dir" ? "目录" : "文件"}</TableCell>
                  <TableCell>{d.updatedAt || "-"}</TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>应用进程</CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="flex justify-end">
            <Button variant="secondary" onClick={refreshProcs} disabled={loadingProcs || !targetId}>
              {loadingProcs ? "刷新中..." : "刷新进程"}
            </Button>
          </div>
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>PID</TableHead>
                <TableHead>命令</TableHead>
                <TableHead>端口</TableHead>
                <TableHead>启动时间</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {processes.map((p) => (
                <TableRow key={p.pid}>
                  <TableCell className="font-medium">{p.pid}</TableCell>
                  <TableCell>{p.name}</TableCell>
                  <TableCell>{p.port ?? "-"}</TableCell>
                  <TableCell>{p.started ?? "-"}</TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </CardContent>
      </Card>
    </div>
  );
}
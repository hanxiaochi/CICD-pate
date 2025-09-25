"use client";

import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { useEffect, useState } from "react";
import { Button } from "@/components/ui/button";

export default function DashboardPage() {
  const [loading, setLoading] = useState(true);
  const [projStats, setProjStats] = useState<{ total: number; git: number; svn: number }>({ total: 0, git: 0, svn: 0 });
  const [targetsTotal, setTargetsTotal] = useState<number | null>(null);
  const [errors, setErrors] = useState<{ projects?: string; targets?: string }>({});
  const [tick, setTick] = useState(0);

  useEffect(() => {
    setErrors({});
    setLoading(true);
    const token = localStorage.getItem("bearer_token") || "";
    (async () => {
      try {
        const res = await fetch("/api/projects", {
          headers: token ? { Authorization: `Bearer ${token}` } : undefined,
          cache: "no-store",
        });
        const data = await res.json();
        const total = Array.isArray(data) ? data.length : 0;
        const git = Array.isArray(data) ? data.filter((p: any) => p.repo_type === "git").length : 0;
        const svn = Array.isArray(data) ? data.filter((p: any) => p.repo_type === "svn").length : 0;
        setProjStats({ total, git, svn });
      } catch {
        setErrors((prev) => ({ ...prev, projects: "failed" }));
      }

      try {
        const res2 = await fetch("/api/targets?pageSize=1", {
          headers: token ? { Authorization: `Bearer ${token}` } : undefined,
          cache: "no-store",
        });
        if (res2.ok) {
          const d = await res2.json();
          setTargetsTotal(typeof d?.total === "number" ? d.total : null);
        } else {
          setErrors((prev) => ({ ...prev, targets: "failed" }));
        }
      } catch {
        setErrors((prev) => ({ ...prev, targets: "failed" }));
      } finally {
        setLoading(false);
      }
    })();
  }, [tick]);

  const hasLive = !loading && (projStats.total > 0 || targetsTotal !== null);

  return (
    <div className="mx-auto max-w-6xl px-6 py-10 space-y-8">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-semibold">项目总览</h1>
        <div className="flex items-center gap-2">
          <Badge variant="secondary">{hasLive ? "实时数据" : "演示界面"}</Badge>
          <Button
            size="sm"
            variant="outline"
            onClick={() => {
              setErrors({});
              setLoading(true);
              setTick((t) => t + 1);
            }}
            disabled={loading}
          >
            {loading ? "刷新中…" : "刷新"}
          </Button>
        </div>
      </div>

      <div className="grid gap-6 sm:grid-cols-2 lg:grid-cols-4">
        <Card>
          <CardHeader>
            <CardTitle>项目数量</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-3xl font-bold">{loading ? "…" : projStats.total || 6}</p>
            <p className="text-xs text-muted-foreground mt-2">
              {loading ? "加载中…" : `Git ${projStats.git || 4} / SVN ${projStats.svn || 2}`}
            </p>
          </CardContent>
        </Card>
        <Card>
          <CardHeader>
            <CardTitle>最近构建</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-3xl font-bold">3 成功</p>
            <p className="text-xs text-muted-foreground mt-2">过去 24 小时</p>
          </CardContent>
        </Card>
        <Card>
          <CardHeader>
            <CardTitle>部署目标</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-3xl font-bold">{loading ? "…" : `${targetsTotal ?? 4} 台`}</p>
            <p className="text-xs text-muted-foreground mt-2">生产 2 / 测试 2</p>
          </CardContent>
        </Card>
        <Card>
          <CardHeader>
            <CardTitle>活跃进程</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-3xl font-bold">8</p>
            <p className="text-xs text-muted-foreground mt-2">Java 5 / Node 3</p>
          </CardContent>
        </Card>
      </div>

      <div className="grid gap-6 lg:grid-cols-2">
        <Card>
          <CardHeader>
            <CardTitle>近期活动</CardTitle>
          </CardHeader>
          <CardContent className="space-y-3 text-sm text-muted-foreground">
            <p>[12:03] 项目 A 构建成功，版本 1.2.3</p>
            <p>[11:48] 部署到 10.0.0.3 完成</p>
            <p>[10:15] 项目 B 发布至测试环境</p>
            <p>[09:02] 同步 SVN 仓库完成</p>
          </CardContent>
        </Card>
        <Card>
          <CardHeader>
            <CardTitle>说明</CardTitle>
          </CardHeader>
          <CardContent className="space-y-3 text-sm text-muted-foreground">
            <p>这里展示轻量级 CI/CD 工具的核心指标与活动流。</p>
            <p>后端将使用 Rails + SQLite3 实现，前端当前为原型界面。</p>
            <p>后续会接入 SSH、Git/SVN、nohup 等实际操作。</p>
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
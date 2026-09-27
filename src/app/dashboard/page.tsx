"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { apiUrl, withAuth } from "@/lib/api";

type Project = { id: number; name: string; vcsType: string; systemName: string | null };
type Target = { id: number; name: string; env: string };
type Deployment = {
  id: number;
  status: string;
  startedAt: number;
  projectName: string;
  targetName: string;
};

export default function DashboardPage() {
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [systemsTotal, setSystemsTotal] = useState(0);
  const [projects, setProjects] = useState<Project[]>([]);
  const [targets, setTargets] = useState<Target[]>([]);
  const [deployments, setDeployments] = useState<Deployment[]>([]);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);

    try {
      const [systemsResponse, projectsResponse, targetsResponse, historyResponse] = await Promise.all([
        fetch(apiUrl("/api/systems"), withAuth()),
        fetch(apiUrl("/api/projects"), withAuth()),
        fetch(apiUrl("/api/targets?pageSize=100"), withAuth()),
        fetch(apiUrl("/api/deployments/history"), withAuth()),
      ]);

      if (![systemsResponse, projectsResponse, targetsResponse, historyResponse].every((response) => response.ok)) {
        throw new Error("部分运营数据加载失败");
      }

      const [systemsData, projectsData, targetsData, historyData] = await Promise.all([
        systemsResponse.json(),
        projectsResponse.json(),
        targetsResponse.json(),
        historyResponse.json(),
      ]);

      setSystemsTotal(Array.isArray(systemsData) ? systemsData.length : 0);
      setProjects(Array.isArray(projectsData) ? projectsData : []);
      setTargets(Array.isArray(targetsData?.items) ? targetsData.items : []);
      setDeployments(Array.isArray(historyData) ? historyData : []);
    } catch (loadError) {
      setError(loadError instanceof Error ? loadError.message : "运营数据加载失败");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void load();
  }, [load]);

  const projectStats = useMemo(() => ({
    git: projects.filter((project) => project.vcsType === "git").length,
    svn: projects.filter((project) => project.vcsType === "svn").length,
  }), [projects]);
  const targetStats = useMemo(() => ({
    prod: targets.filter((target) => target.env === "prod").length,
    staging: targets.filter((target) => target.env === "staging").length,
    dev: targets.filter((target) => target.env === "dev").length,
  }), [targets]);
  const deploymentStats = useMemo(() => ({
    success: deployments.filter((deployment) => deployment.status === "success").length,
    failed: deployments.filter((deployment) => deployment.status === "failed").length,
  }), [deployments]);

  return (
    <div className="mx-auto max-w-6xl px-6 py-10 space-y-8">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h1 className="text-2xl font-semibold">交付运行总览</h1>
          <p className="mt-1 text-sm text-muted-foreground">系统、项目、目标机与发布记录来自当前数据库。</p>
        </div>
        <div className="flex items-center gap-2">
          <Badge variant="secondary">本地持久化数据</Badge>
          <Button size="sm" variant="outline" onClick={() => void load()} disabled={loading}>
            {loading ? "刷新中..." : "刷新"}
          </Button>
        </div>
      </div>

      {error && <p className="text-sm text-destructive">{error}</p>}

      <div className="grid gap-6 sm:grid-cols-2 lg:grid-cols-4">
        <Card>
          <CardHeader><CardTitle>业务系统</CardTitle></CardHeader>
          <CardContent>
            <p className="text-3xl font-bold">{loading ? "..." : systemsTotal}</p>
            <p className="mt-2 text-xs text-muted-foreground">按系统组织项目与发布</p>
          </CardContent>
        </Card>
        <Card>
          <CardHeader><CardTitle>交付项目</CardTitle></CardHeader>
          <CardContent>
            <p className="text-3xl font-bold">{loading ? "..." : projects.length}</p>
            <p className="mt-2 text-xs text-muted-foreground">Git {projectStats.git} / SVN {projectStats.svn}</p>
          </CardContent>
        </Card>
        <Card>
          <CardHeader><CardTitle>受控目标</CardTitle></CardHeader>
          <CardContent>
            <p className="text-3xl font-bold">{loading ? "..." : targets.length}</p>
            <p className="mt-2 text-xs text-muted-foreground">生产 {targetStats.prod} / 预发 {targetStats.staging} / 开发 {targetStats.dev}</p>
          </CardContent>
        </Card>
        <Card>
          <CardHeader><CardTitle>发布记录</CardTitle></CardHeader>
          <CardContent>
            <p className="text-3xl font-bold">{loading ? "..." : deployments.length}</p>
            <p className="mt-2 text-xs text-muted-foreground">成功 {deploymentStats.success} / 失败 {deploymentStats.failed}</p>
          </CardContent>
        </Card>
      </div>

      <div className="grid gap-6 lg:grid-cols-2">
        <Card>
          <CardHeader><CardTitle>最近发布</CardTitle></CardHeader>
          <CardContent className="space-y-3">
            {deployments.slice(0, 4).map((deployment) => (
              <div key={deployment.id} className="flex items-center justify-between gap-4 text-sm">
                <div className="min-w-0">
                  <p className="truncate font-medium">{deployment.projectName}</p>
                  <p className="truncate text-xs text-muted-foreground">{deployment.targetName} · {new Date(deployment.startedAt).toLocaleString()}</p>
                </div>
                <Badge variant={deployment.status === "success" ? "secondary" : "destructive"}>
                  {deployment.status === "success" ? "成功" : "失败"}
                </Badge>
              </div>
            ))}
            {!loading && deployments.length === 0 && <p className="text-sm text-muted-foreground">暂无发布记录</p>}
          </CardContent>
        </Card>
        <Card>
          <CardHeader><CardTitle>运行边界</CardTitle></CardHeader>
          <CardContent className="space-y-3 text-sm text-muted-foreground">
            <p>面板将项目、目标机、发布步骤、回滚和远程控制统一到可审查的操作路径。</p>
            <p>当前作品集数据全部为合成数据，目标地址均指向本机且不包含 SSH 凭据。</p>
            <p>真实环境仍需完成身份体系、RBAC、命令与路径白名单、目标机验收和独立安全评审。</p>
          </CardContent>
        </Card>
      </div>
    </div>
  );
}

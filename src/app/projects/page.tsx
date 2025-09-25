"use client";

import { useEffect, useState } from "react";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { toast } from "sonner";
import { apiUrl, withAuth } from "@/lib/api";

export default function ProjectsPage() {
  const [repoType, setRepoType] = useState("git");
  const [name, setName] = useState("");
  const [repoUrl, setRepoUrl] = useState("");
  const [branch, setBranch] = useState("");
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const [pipeline, setPipeline] = useState("");
  const [saving, setSaving] = useState(false);
  const [testing, setTesting] = useState(false);
  const [loadingList, setLoadingList] = useState(false);
  const [projects, setProjects] = useState<any[]>([]);
  const [systems, setSystems] = useState<Array<{ id: number; name: string }>>([]);
  const [systemId, setSystemId] = useState<string>("none");
  const [creatingSystem, setCreatingSystem] = useState(false);
  const [newSystemName, setNewSystemName] = useState("");

  useEffect(() => {
    const load = async () => {
      setLoadingList(true);
      try {
        const [resP, resS] = await Promise.all([
          fetch(apiUrl("/api/projects"), withAuth()),
          fetch(apiUrl("/api/systems"), withAuth()),
        ]);
        const data = await resP.json();
        setProjects(Array.isArray(data) ? data : []);
        const sys = await resS.json();
        setSystems(Array.isArray(sys) ? sys : []);
      } catch (e) {
        toast.error("加载项目或系统失败");
      } finally {
        setLoadingList(false);
      }
    };
    load();
  }, []);

  async function refreshList() {
    setLoadingList(true);
    try {
      const [resP, resS] = await Promise.all([
        fetch(apiUrl("/api/projects"), withAuth()),
        fetch(apiUrl("/api/systems"), withAuth()),
      ]);
      const data = await resP.json();
      setProjects(Array.isArray(data) ? data : []);
      const sys = await resS.json();
      setSystems(Array.isArray(sys) ? sys : []);
    } catch (e) {
      toast.error("刷新失败");
    } finally {
      setLoadingList(false);
    }
  }

  async function handleTestConnection() {
    if (!repoUrl) {
      toast.error("请填写仓库地址");
      return;
    }
    setTesting(true);
    try {
      const res = await fetch(apiUrl("/api/projects/test-connection"), withAuth({
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ repo_url: repoUrl }),
      }));
      const j = await res.json();
      if (!res.ok || !j.ok) throw new Error(j?.error || "连接失败");
      toast.success(j.details || "连接成功");
    } catch (e: any) {
      toast.error(e?.message || "连接失败");
    } finally {
      setTesting(false);
    }
  }

  async function handleSave() {
    if (!name || !repoUrl) {
      toast.error("请填写项目名称与仓库地址");
      return;
    }
    setSaving(true);
    try {
      const res = await fetch(apiUrl("/api/projects"), withAuth({
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          name,
          repo_type: repoType,
          repo_url: repoUrl,
          branch,
          credentials_json: username || password ? { username, password } : undefined,
          pipeline,
          system_id: systemId && systemId !== "none" ? Number(systemId) : undefined,
        }),
      }));
      if (!res.ok) {
        const j = await res.json().catch(() => ({}));
        throw new Error(j?.error || "保存失败");
      }
      const item = await res.json();
      toast.success("保存成功");
      setProjects((prev) => [item, ...prev]);
      setName("");
      setRepoUrl("");
      setBranch("");
      setUsername("");
      setPassword("");
      setPipeline("");
      setSystemId("none");
    } catch (e: any) {
      toast.error(e?.message || "保存失败");
    } finally {
      setSaving(false);
    }
  }

  async function handleCreateSystem() {
    if (!newSystemName.trim()) {
      toast.error("请输入系统名称");
      return;
    }
    setCreatingSystem(true);
    try {
      const res = await fetch(apiUrl("/api/systems"), withAuth({
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ name: newSystemName.trim() }),
      }));
      const j = await res.json();
      if (!res.ok) throw new Error(j?.error || "创建失败");
      setSystems((s) => [j, ...s]);
      setNewSystemName("");
      toast.success("已创建系统");
    } catch (e: any) {
      toast.error(e?.message || "创建失败");
    } finally {
      setCreatingSystem(false);
    }
  }

  async function handleAssignSystem(projectId: number, sid: string) {
    try {
      const res = await fetch(apiUrl("/api/projects/assign"), withAuth({
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ project_id: projectId, system_id: sid && sid !== "none" ? Number(sid) : null }),
      }));
      const j = await res.json();
      if (!res.ok) throw new Error(j?.error || "分配失败");
      setProjects((prev) => prev.map((p) => (p.id === projectId ? { ...p, system_id: j.project.system_id } : p)));
      toast.success("已更新所属系统");
    } catch (e: any) {
      toast.error(e?.message || "分配失败");
    }
  }

  return (
    <div className="mx-auto max-w-6xl px-6 py-10 space-y-8">
      <h1 className="text-2xl font-semibold">项目与仓库配置</h1>

      <Card>
        <CardHeader>
          <CardTitle>新建系统</CardTitle>
        </CardHeader>
        <CardContent className="grid gap-4 sm:grid-cols-[1fr_auto] items-end">
          <div className="space-y-2">
            <Label htmlFor="sysName">系统名称</Label>
            <Input id="sysName" placeholder="例如：A系统" value={newSystemName} onChange={(e) => setNewSystemName(e.target.value)} />
          </div>
          <Button onClick={handleCreateSystem} disabled={creatingSystem}>
            {creatingSystem ? "创建中..." : "创建系统"}
          </Button>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>新建项目</CardTitle>
        </CardHeader>
        <CardContent className="grid gap-6">
          <div className="grid gap-3 sm:grid-cols-2">
            <div className="space-y-2">
              <Label htmlFor="name">项目名称</Label>
              <Input id="name" placeholder="例如：商城后端" value={name} onChange={(e) => setName(e.target.value)} />
            </div>
            <div className="space-y-2">
              <Label htmlFor="type">仓库类型</Label>
              <Select value={repoType} onValueChange={setRepoType}>
                <SelectTrigger id="type">
                  <SelectValue placeholder="选择仓库类型" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="git">Git</SelectItem>
                  <SelectItem value="svn">SVN</SelectItem>
                </SelectContent>
              </Select>
            </div>
          </div>

          <div className="grid gap-3 sm:grid-cols-2">
            <div className="space-y-2">
              <Label htmlFor="system">所属系统（可选）</Label>
              <Select value={systemId} onValueChange={setSystemId}>
                <SelectTrigger id="system">
                  <SelectValue placeholder="未分配" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="none">未分配</SelectItem>
                  {systems.map((s) => (
                    <SelectItem key={s.id} value={String(s.id)}>{s.name}</SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
          </div>

          <div className="grid gap-3 sm:grid-cols-2">
            <div className="space-y-2">
              <Label htmlFor="repoUrl">仓库地址</Label>
              <Input id="repoUrl" placeholder="https://github.com/org/repo.git 或 svn://..." value={repoUrl} onChange={(e) => setRepoUrl(e.target.value)} />
            </div>
            <div className="space-y-2">
              <Label htmlFor="branch">分支/版本</Label>
              <Input id="branch" placeholder="main 或 trunk/tags/v1.0" value={branch} onChange={(e) => setBranch(e.target.value)} />
            </div>
          </div>

          <div className="grid gap-3 sm:grid-cols-2">
            <div className="space-y-2">
              <Label htmlFor="username">用户名（可选）</Label>
              <Input id="username" placeholder="仅私有仓库需要" value={username} onChange={(e) => setUsername(e.target.value)} />
            </div>
            <div className="space-y-2">
              <Label htmlFor="password">密码/Token（可选）</Label>
              <Input id="password" type="password" autoComplete="off" placeholder="仅私有仓库需要" value={password} onChange={(e) => setPassword(e.target.value)} />
            </div>
          </div>

          <div className="space-y-2">
            <Label htmlFor="pipeline">构建流水线（每行一条命令）</Label>
            <Textarea id="pipeline" rows={6} value={pipeline} onChange={(e) => setPipeline(e.target.value)} placeholder={`示例（Java Maven）：\n- mvn clean package -DskipTests\n- cp target/app.jar dist/\n\n示例（Node）：\n- pnpm i\n- pnpm build\n- tar -czf dist.tar.gz .next`}></Textarea>
          </div>

          <div className="flex justify-end gap-3">
            <Button variant="secondary" onClick={handleTestConnection} disabled={testing || !repoUrl}>
              {testing ? "测试中..." : "测试连接"}
            </Button>
            <Button onClick={handleSave} disabled={saving || !name || !repoUrl}>
              {saving ? "保存中..." : "保存项目"}
            </Button>
          </div>
        </CardContent>
      </Card>

      <Card>
        <CardHeader className="flex flex-row items-center justify-between space-y-0">
          <CardTitle>已有项目</CardTitle>
          <div className="flex items-center gap-2">
            <Button variant="secondary" size="sm" onClick={refreshList} disabled={loadingList}>
              {loadingList ? "刷新中..." : "刷新"}
            </Button>
          </div>
        </CardHeader>
        <CardContent className="text-sm text-muted-foreground">
          {loadingList ? (
            <div>加载中...</div>
          ) : projects.length === 0 ? (
            <div>暂无数据，保存后在此展示项目列表与构建历史。</div>
          ) : (
            <ul className="space-y-2 text-foreground">
              {projects.map((p) => (
                <li key={p.id} className="flex items-center justify-between border rounded-md px-3 py-2 gap-3">
                  <div className="flex-1 min-w-0">
                    <span className="font-medium">{p.name}</span>
                    <span className="ml-2 text-xs text-muted-foreground">{p.repo_type} · {p.branch}</span>
                  </div>
                  <div className="flex items-center gap-2">
                    <span className="text-xs text-muted-foreground hidden sm:inline">系统</span>
                    <Select value={p.system_id ? String(p.system_id) : "none"} onValueChange={(v) => handleAssignSystem(p.id, v)}>
                      <SelectTrigger className="w-[160px]">
                        <SelectValue placeholder="未分配" />
                      </SelectTrigger>
                      <SelectContent>
                        <SelectItem value="none">未分配</SelectItem>
                        {systems.map((s) => (
                          <SelectItem key={s.id} value={String(s.id)}>{s.name}</SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                  </div>
                </li>
              ))}
            </ul>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
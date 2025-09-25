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

  useEffect(() => {
    const load = async () => {
      setLoadingList(true);
      try {
        const res = await fetch(apiUrl("/api/projects"), withAuth());
        const data = await res.json();
        setProjects(Array.isArray(data) ? data : []);
      } catch (e) {
        toast.error("加载项目失败");
      } finally {
        setLoadingList(false);
      }
    };
    load();
  }, []);

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
    } catch (e: any) {
      toast.error(e?.message || "保存失败");
    } finally {
      setSaving(false);
    }
  }

  return (
    <div className="mx-auto max-w-6xl px-6 py-10 space-y-8">
      <h1 className="text-2xl font-semibold">项目与仓库配置</h1>

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
              <Input id="password" type="password" placeholder="仅私有仓库需要" value={password} onChange={(e) => setPassword(e.target.value)} />
            </div>
          </div>

          <div className="space-y-2">
            <Label htmlFor="pipeline">构建流水线（每行一条命令）</Label>
            <Textarea id="pipeline" rows={6} value={pipeline} onChange={(e) => setPipeline(e.target.value)} placeholder={`示例（Java Maven）：\n- mvn clean package -DskipTests\n- cp target/app.jar dist/\n\n示例（Node）：\n- pnpm i\n- pnpm build\n- tar -czf dist.tar.gz .next`}></Textarea>
          </div>

          <div className="flex justify-end gap-3">
            <Button variant="secondary" onClick={handleTestConnection} disabled={testing}>
              {testing ? "测试中..." : "测试连接"}
            </Button>
            <Button onClick={handleSave} disabled={saving}>
              {saving ? "保存中..." : "保存项目"}
            </Button>
          </div>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>已有项目</CardTitle>
        </CardHeader>
        <CardContent className="text-sm text-muted-foreground">
          {loadingList ? (
            <div>加载中...</div>
          ) : projects.length === 0 ? (
            <div>暂无数据，保存后在此展示项目列表与构建历史。</div>
          ) : (
            <ul className="space-y-2 text-foreground">
              {projects.map((p) => (
                <li key={p.id} className="flex items-center justify-between border rounded-md px-3 py-2">
                  <span className="font-medium">{p.name}</span>
                  <span className="text-xs text-muted-foreground">{p.repo_type} · {p.branch}</span>
                </li>
              ))}
            </ul>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
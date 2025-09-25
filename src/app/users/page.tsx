"use client";

import { useState, useEffect } from "react";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Checkbox } from "@/components/ui/checkbox";
import { apiUrl, withAuth } from "@/lib/api";
import { toast } from "sonner";
import { Switch } from "@/components/ui/switch";
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
  AlertDialogTrigger,
} from "@/components/ui/alert-dialog";

export default function UsersPage() {
  const [users, setUsers] = useState([
    // initial data now loaded from API
  ] as Array<{ id: number; name: string; email: string; role: string; scopes: string[]; status?: string }>);
  const [isLoading, setIsLoading] = useState(true);
  const [creating, setCreating] = useState(false);
  const [savingId, setSavingId] = useState<number | null>(null);
  const [deletingId, setDeletingId] = useState<number | null>(null);
  const [search, setSearch] = useState("");
  const [roleFilter, setRoleFilter] = useState<"all" | "admin" | "developer" | "viewer">("all");
  const [statusFilter, setStatusFilter] = useState<"all" | "active" | "disabled">("all");

  const [form, setForm] = useState({ name: "", email: "", role: "viewer" });
  const allScopes = [
    { key: "projects", label: "项目" },
    { key: "pipelines", label: "流水线" },
    { key: "deployments", label: "部署" },
    { key: "control", label: "应用控制" },
  ];

  // unified loader
  async function loadUsers() {
    try {
      setIsLoading(true);
      const res = await fetch(apiUrl("/api/users"), withAuth());
      const json = await res.json();
      if (!res.ok || !json?.success) throw new Error(json?.error || "加载失败");
      setUsers(json.data || []);
    } catch (e: any) {
      toast.error(e?.message || "无法加载用户列表");
    } finally {
      setIsLoading(false);
    }
  }

  useEffect(() => {
    loadUsers();
  }, []);

  async function toggleScope(userId: number, key: string) {
    const prev = users;
    const next = users.map((u) => {
      if (u.id !== userId) return u;
      const has = u.scopes.includes(key);
      return { ...u, scopes: has ? u.scopes.filter((s) => s !== key) : [...u.scopes, key] };
    });
    setUsers(next);
    setSavingId(userId);
    try {
      const target = next.find((u) => u.id === userId)!;
      const res = await fetch(apiUrl(`/api/users/${userId}`), withAuth({
        method: "PATCH",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ scopes: target.scopes }),
      }));
      const json = await res.json();
      if (!res.ok || !json?.success) throw new Error(json?.error || "保存失败");
      // ensure sync with backend response
      setUsers((cur) => cur.map((u) => (u.id === userId ? json.data : u)));
      toast.success("已更新权限范围");
    } catch (e: any) {
      setUsers(prev);
      toast.error(e?.message || "更新权限失败");
    } finally {
      setSavingId(null);
    }
  }

  async function updateRole(userId: number, role: string) {
    const prev = users;
    setUsers((cur) => cur.map((u) => (u.id === userId ? { ...u, role } : u)));
    setSavingId(userId);
    try {
      const res = await fetch(apiUrl(`/api/users/${userId}`), withAuth({
        method: "PATCH",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ role }),
      }));
      const json = await res.json();
      if (!res.ok || !json?.success) throw new Error(json?.error || "保存失败");
      setUsers((cur) => cur.map((u) => (u.id === userId ? json.data : u)));
      toast.success("角色已更新");
    } catch (e: any) {
      setUsers(prev);
      toast.error(e?.message || "更新角色失败");
    } finally {
      setSavingId(null);
    }
  }

  async function toggleStatus(userId: number, nextChecked: boolean) {
    const prev = users;
    const nextStatus = nextChecked ? "active" : "disabled";
    setUsers((cur) => cur.map((u) => (u.id === userId ? { ...u, status: nextStatus } : u)));
    setSavingId(userId);
    try {
      const res = await fetch(apiUrl(`/api/users/${userId}`), withAuth({
        method: "PATCH",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ status: nextStatus }),
      }));
      const json = await res.json();
      if (!res.ok || !json?.success) throw new Error(json?.error || "保存失败");
      setUsers((cur) => cur.map((u) => (u.id === userId ? json.data : u)));
      toast.success(nextChecked ? "已启用用户" : "已禁用用户");
    } catch (e: any) {
      setUsers(prev);
      toast.error(e?.message || "更新状态失败");
    } finally {
      setSavingId(null);
    }
  }

  async function deleteUser(userId: number) {
    setDeletingId(userId);
    try {
      const res = await fetch(apiUrl(`/api/users/${userId}`), withAuth({ method: "DELETE" }));
      const json = await res.json();
      if (!res.ok || !json?.success) throw new Error(json?.error || "删除失败");
      setUsers((cur) => cur.filter((u) => u.id !== userId));
      toast.success("用户已删除");
    } catch (e: any) {
      toast.error(e?.message || "删除用户失败");
    } finally {
      setDeletingId(null);
    }
  }

  async function addUser() {
    if (!form.name || !form.email) return;
    setCreating(true);
    try {
      const res = await fetch(apiUrl("/api/users"), withAuth({
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ name: form.name, email: form.email, role: form.role }),
      }));
      const json = await res.json();
      if (!res.ok || !json?.success) throw new Error(json?.error || "创建失败");
      setUsers((cur) => [...cur, json.data]);
      setForm({ name: "", email: "", role: "viewer" });
      toast.success("用户已创建");
    } catch (e: any) {
      toast.error(e?.message || "创建用户失败");
    } finally {
      setCreating(false);
    }
  }

  // derived filtered users
  const filteredUsers = users.filter((u) => {
    const q = search.trim().toLowerCase();
    const matchQuery = !q || u.name.toLowerCase().includes(q) || u.email.toLowerCase().includes(q);
    const matchRole = roleFilter === "all" || u.role === roleFilter;
    const curStatus = (u.status ?? "active") as "active" | "disabled";
    const matchStatus = statusFilter === "all" || curStatus === statusFilter;
    return matchQuery && matchRole && matchStatus;
  });

  return (
    <div className="mx-auto max-w-6xl px-6 py-10 space-y-8">
      <h1 className="text-2xl font-semibold">用户与权限</h1>

      <Card>
        <CardHeader>
          <CardTitle>新建用户</CardTitle>
        </CardHeader>
        <CardContent className="grid gap-4 sm:grid-cols-3">
          <div className="space-y-2">
            <Label htmlFor="name">姓名</Label>
            <Input id="name" value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} placeholder="张三" />
          </div>
          <div className="space-y-2">
            <Label htmlFor="email">邮箱</Label>
            <Input id="email" value={form.email} onChange={(e) => setForm({ ...form, email: e.target.value })} placeholder="user@example.com" />
          </div>
          <div className="space-y-2">
            <Label htmlFor="role">角色</Label>
            <Select value={form.role} onValueChange={(v) => setForm({ ...form, role: v })}>
              <SelectTrigger id="role">
                <SelectValue placeholder="选择角色" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="admin">管理员</SelectItem>
                <SelectItem value="developer">开发者</SelectItem>
                <SelectItem value="viewer">访客</SelectItem>
              </SelectContent>
            </Select>
          </div>
          <div className="sm:col-span-3 flex justify-end items-end">
            <Button onClick={addUser} disabled={creating || !form.name || !form.email}>
              {creating ? "创建中..." : "添加用户"}
            </Button>
          </div>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <div className="flex items-center justify-between">
            <CardTitle>用户列表与权限范围</CardTitle>
            <Button variant="secondary" size="sm" onClick={loadUsers} disabled={isLoading}>
              {isLoading ? "刷新中..." : "刷新"}
            </Button>
          </div>
        </CardHeader>
        <CardContent>
          {/* Filters */}
          <div className="mb-4 grid gap-3 sm:flex sm:items-center sm:gap-4">
            <div className="sm:w-64">
              <Input
                placeholder="搜索姓名或邮箱"
                value={search}
                onChange={(e) => setSearch(e.target.value)}
              />
            </div>
            <div className="sm:w-44">
              <Select value={roleFilter} onValueChange={(v) => setRoleFilter(v as any)}>
                <SelectTrigger>
                  <SelectValue placeholder="角色筛选" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="all">全部角色</SelectItem>
                  <SelectItem value="admin">管理员</SelectItem>
                  <SelectItem value="developer">开发者</SelectItem>
                  <SelectItem value="viewer">访客</SelectItem>
                </SelectContent>
              </Select>
            </div>
            <div className="sm:w-40">
              <Select value={statusFilter} onValueChange={(v) => setStatusFilter(v as any)}>
                <SelectTrigger>
                  <SelectValue placeholder="状态筛选" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="all">全部状态</SelectItem>
                  <SelectItem value="active">启用</SelectItem>
                  <SelectItem value="disabled">禁用</SelectItem>
                </SelectContent>
              </Select>
            </div>
          </div>

          {/* Simple loading state */}
          {isLoading ? (
            <div className="text-sm text-muted-foreground">加载中...</div>
          ) : (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>姓名</TableHead>
                  <TableHead>邮箱</TableHead>
                  <TableHead>角色</TableHead>
                  <TableHead>权限范围</TableHead>
                  <TableHead>状态</TableHead>
                  <TableHead className="w-24">操作</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {filteredUsers.map((u) => (
                  <TableRow key={u.id}>
                    <TableCell className="font-medium">{u.name}</TableCell>
                    <TableCell>{u.email}</TableCell>
                    <TableCell className="min-w-40">
                      <Select value={u.role} onValueChange={(v) => updateRole(u.id, v)} disabled={savingId === u.id}>
                        <SelectTrigger>
                          <SelectValue placeholder="选择角色" />
                        </SelectTrigger>
                        <SelectContent>
                          <SelectItem value="admin">管理员</SelectItem>
                          <SelectItem value="developer">开发者</SelectItem>
                          <SelectItem value="viewer">访客</SelectItem>
                        </SelectContent>
                      </Select>
                    </TableCell>
                    <TableCell>
                      <div className="flex flex-wrap gap-4">
                        {allScopes.map((s) => (
                          <label key={s.key} className="flex items-center gap-2 text-sm opacity-100">
                            <Checkbox checked={u.scopes.includes(s.key)} onCheckedChange={() => toggleScope(u.id, s.key)} disabled={savingId === u.id} />
                            {s.label}
                          </label>
                        ))}
                      </div>
                    </TableCell>
                    <TableCell>
                      <div className="flex items-center gap-2">
                        <Switch
                          checked={(u.status ?? "active") === "active"}
                          onCheckedChange={(val) => toggleStatus(u.id, Boolean(val))}
                          disabled={savingId === u.id}
                        />
                        <span className="text-sm text-muted-foreground">{(u.status ?? "active") === "active" ? "启用" : "禁用"}</span>
                      </div>
                    </TableCell>
                    <TableCell>
                      <AlertDialog>
                        <AlertDialogTrigger asChild>
                          <Button
                            variant="destructive"
                            size="sm"
                            disabled={deletingId === u.id || savingId === u.id}
                          >
                            {deletingId === u.id ? "删除中..." : "删除"}
                          </Button>
                        </AlertDialogTrigger>
                        <AlertDialogContent>
                          <AlertDialogHeader>
                            <AlertDialogTitle>确认删除</AlertDialogTitle>
                            <AlertDialogDescription>
                              确认删除用户 {u.name}（{u.email}）？该操作不可撤销。
                            </AlertDialogDescription>
                          </AlertDialogHeader>
                          <AlertDialogFooter>
                            <AlertDialogCancel>取消</AlertDialogCancel>
                            <AlertDialogAction onClick={() => deleteUser(u.id)}>
                              确认删除
                            </AlertDialogAction>
                          </AlertDialogFooter>
                        </AlertDialogContent>
                      </AlertDialog>
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
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
import Link from "next/link";
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from "@/components/ui/alert-dialog";

export default function DeploymentsPage() {
  const [root, setRoot] = useState("/opt/apps");
  const [targets, setTargets] = useState<any[]>([]);
  // 新增：系统-项目-成品包级联状态
  const [systems, setSystems] = useState<Array<{ id: number; name: string }>>([]);
  const [projList, setProjList] = useState<any[]>([]);
  const [pkgList, setPkgList] = useState<any[]>([]);
  const [selSystemId, setSelSystemId] = useState<string>("");
  const [selProjectId, setSelProjectId] = useState<string>("");
  const [selPackageId, setSelPackageId] = useState<string>("");
  const [loadingCascade, setLoadingCascade] = useState(false);
  const [loadingPkgs, setLoadingPkgs] = useState(false);
  const [targetId, setTargetId] = useState<string>("1");
  const [loadingTargets, setLoadingTargets] = useState(false);
  const [loadingFs, setLoadingFs] = useState(false);
  const [loadingProcs, setLoadingProcs] = useState(false);
  // 新增：发布进行中状态
  const [publishing, setPublishing] = useState(false);
  // 新增：发布步骤与结果
  const [deploySteps, setDeploySteps] = useState<Array<{ key: string; label: string; ok: boolean }>>([]);
  const [lastDeploymentId, setLastDeploymentId] = useState<number | null>(null);
  // 新增：本地缓存 key
  const LS_KEYS = {
    system: "deploy.sel.systemId",
    project: "deploy.sel.projectId",
    pkg: "deploy.sel.packageId",
    target: "deploy.sel.targetId",
  } as const;
  // 新增：环境筛选
  const [filterEnv, setFilterEnv] = useState<string>("");
  const [directories, setDirectories] = useState<{ name: string; type: string; updatedAt?: string }[]>([]);
  const [processes, setProcesses] = useState<{ pid: number; name: string; port?: number; started?: string }[]>([]);
  const [confirmOpen, setConfirmOpen] = useState(false);
  const [pendingDeleteId, setPendingDeleteId] = useState<number | null>(null);
  const [newTarget, setNewTarget] = useState({
    name: "",
    host: "",
    ssh_user: "root",
    ssh_port: 22,
    root_path: "/opt/apps",
    auth_type: "password" as "password" | "key",
    password: "",
    private_key: "",
    passphrase: "",
    env: "prod" as "dev" | "staging" | "prod",
    options: { storeCredentials: true },
  });
  const [loadingTest, setLoadingTest] = useState(false);
  const [loadingCreate, setLoadingCreate] = useState(false);

  // pagination & search state
  const [page, setPage] = useState(1);
  const [pageSize] = useState(10);
  const [q, setQ] = useState("");
  const [total, setTotal] = useState(0);

  // edit mode
  const [editingId, setEditingId] = useState<number | null>(null);
  const [editTarget, setEditTarget] = useState<any | null>(null);
  const [savingEdit, setSavingEdit] = useState(false);
  const [deletingId, setDeletingId] = useState<number | null>(null);

  // batch test state
  const [batchHosts, setBatchHosts] = useState("");
  const [batchOpts, setBatchOpts] = useState({ timeoutMs: 6000, retries: 0, concurrency: 5 });
  const [batchLoading, setBatchLoading] = useState(false);
  const [batchResults, setBatchResults] = useState<Array<{ host: string; ok: boolean; latencyMs?: number; error?: string }>>([]);

  // 新增：加载系统与项目用于级联
  useEffect(() => {
    const loadCascade = async () => {
      setLoadingCascade(true);
      try {
        const [resSys, resProj] = await Promise.all([
          fetch(apiUrl("/api/systems"), withAuth()),
          fetch(apiUrl("/api/projects"), withAuth()),
        ]);
        const sys = await resSys.json();
        const projs = await resProj.json();
        setSystems(Array.isArray(sys) ? sys : []);
        setProjList(Array.isArray(projs) ? projs : []);
        // 新增：恢复本地缓存的系统/项目
        const cachedSys = localStorage.getItem(LS_KEYS.system) || "";
        const cachedProj = localStorage.getItem(LS_KEYS.project) || "";
        if (cachedSys && (Array.isArray(sys) ? sys : []).some((s: any) => String(s.id) === cachedSys)) {
          setSelSystemId(cachedSys);
          if (
            cachedProj &&
            (Array.isArray(projs) ? projs : []).some(
              (p: any) => String(p.id) === cachedProj && String(p.system_id) === cachedSys
            )
          ) {
            setSelProjectId(cachedProj);
          }
        }
      } catch (_e) {
        toast.error("加载系统/项目失败");
      } finally {
        setLoadingCascade(false);
      }
    };
    loadCascade();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // 新增：选择项目后加载成品包
  useEffect(() => {
    const pid = Number(selProjectId);
    if (!selProjectId || !Number.isFinite(pid)) {
      setPkgList([]);
      setSelPackageId("");
      return;
    }
    const loadPkgs = async () => {
      setLoadingPkgs(true);
      try {
        const res = await fetch(apiUrl(`/api/projects/${pid}/packages`), withAuth());
        const list = await res.json();
        setPkgList(Array.isArray(list) ? list : []);
        // 新增：恢复本地缓存的成品包（需在包列表加载后）
        const cachedPkg = localStorage.getItem(LS_KEYS.pkg) || "";
        if (cachedPkg && Array.isArray(list) && list.some((k: any) => String(k.id) === cachedPkg)) {
          setSelPackageId(cachedPkg);
        }
      } catch (_e) {
        toast.error("加载成品包失败");
      } finally {
        setLoadingPkgs(false);
      }
    };
    loadPkgs();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [selProjectId]);

  // load targets (paginated)
  useEffect(() => {
    const loadTargets = async () => {
      setLoadingTargets(true);
      try {
        const url = apiUrl(`/api/targets?page=${page}&pageSize=${pageSize}&q=${encodeURIComponent(q)}`);
        const res = await fetch(url, withAuth());
        const data = await res.json();
        if (!res.ok) throw new Error(data?.error || "加载目标服务器失败");
        // expects { items, total, page, pageSize }
        setTargets(Array.isArray(data.items) ? data.items : []);
        setTotal(data.total || 0);
        const cachedTarget = localStorage.getItem(LS_KEYS.target) || "";
        if (Array.isArray(data.items) && data.items.length > 0) {
          // 优先恢复缓存的目标ID，其次默认选第一项
          const found = cachedTarget && data.items.some((t: any) => String(t.id) === cachedTarget);
          setTargetId(found ? String(cachedTarget) : String(data.items[0].id));
        }
      } catch (e) {
        toast.error("加载目标服务器失败");
      } finally {
        setLoadingTargets(false);
      }
    };
    loadTargets();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [page, pageSize, q]);

  async function testConnection() {
    if (!newTarget.host) {
      toast.error("请填写主机地址（host）");
      return;
    }
    setLoadingTest(true);
    try {
      const init = withAuth();
      const payload: any = {
        host: newTarget.host,
        ssh_user: newTarget.ssh_user,
        ssh_port: newTarget.ssh_port,
        auth_type: newTarget.auth_type,
        // enhanced options
        timeout: 6000,
      };
      if (newTarget.auth_type === "password") {
        payload.password = newTarget.password || "";
      } else {
        payload.private_key = newTarget.private_key || "";
        if (newTarget.passphrase) payload.passphrase = newTarget.passphrase;
      }
      const res = await fetch(
        apiUrl("/api/targets/test-ssh"),
        { ...init, method: "POST", headers: { "Content-Type": "application/json", ...(init as any).headers }, body: JSON.stringify(payload) }
      );
      const j = await res.json();
      if (!res.ok) throw new Error(j?.error || "连接失败");
      if (!j.ok) throw new Error(j?.error || "SSH 连接失败");
      toast.success(`SSH 连接成功，用时 ${j.latencyMs ?? "-"}ms`);
    } catch (e: any) {
      toast.error(e?.message || "连接失败");
    } finally {
      setLoadingTest(false);
    }
  }

  async function createTarget() {
    if (!newTarget.name || !newTarget.host) {
      toast.error("请填写名称与主机地址");
      return;
    }
    if (newTarget.auth_type === "key" && !newTarget.private_key.trim()) {
      toast.error("选择私钥认证时，必须提供私钥内容或上传文件");
      return;
    }
    setLoadingCreate(true);
    try {
      const init = withAuth();
      const res = await fetch(
        apiUrl("/api/targets"),
        { ...init, method: "POST", headers: { "Content-Type": "application/json", ...(init as any).headers }, body: JSON.stringify(newTarget) }
      );
      const j = await res.json();
      if (!res.ok) throw new Error(j?.error || "保存失败");
      toast.success("已添加目标服务器");
      // reload current page
      setNewTarget((s) => ({ ...s, name: "", host: "", password: "", private_key: "", passphrase: "" }));
      // trigger reload
      setPage(1);
      setQ("");
    } catch (e: any) {
      toast.error(e?.message || "保存失败");
    } finally {
      setLoadingCreate(false);
    }
  }

  async function refreshFs() {
    if (!targetId) return;
    setLoadingFs(true);
    try {
      const res = await fetch(apiUrl(`/api/targets/${targetId}/fs?path=${encodeURIComponent(root)}`), withAuth());
      const j = await res.json();
      if (!res.ok) throw new Error(j?.error || "读取目录失败");
      const list = (j.entries || []).map((it: any) => ({
        name: it.name,
        type: it.type === "directory" ? "dir" : it.type === "file" ? "file" : it.type,
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
        started: p.started_at ? p.started_at : undefined,
      }));
      setProcesses(list);
      toast.success("进程已刷新");
    } catch (e: any) {
      toast.error(e?.message || "读取进程失败");
    } finally {
      setLoadingProcs(false);
    }
  }

  const handleKeyUpload = async (file?: File | null) => {
    if (!file) return;
    try {
      const text = await file.text();
      setNewTarget((s) => ({ ...s, private_key: text }));
      toast.success("已读取私钥文件");
    } catch {
      toast.error("读取私钥文件失败");
    }
  };

  // edit helpers
  const startEdit = (t: any) => {
    setEditingId(t.id);
    setEditTarget({
      name: t.name,
      host: t.host,
      ssh_user: t.sshUser,
      ssh_port: t.sshPort,
      root_path: t.rootPath,
      auth_type: t.authType,
      env: t.env || "prod",
      password: "", // 不展示密文，允许覆盖
      private_key: "",
      passphrase: "",
    });
  };

  const cancelEdit = () => {
    setEditingId(null);
    setEditTarget(null);
  };

  const saveEdit = async () => {
    if (!editingId || !editTarget) return;
    setSavingEdit(true);
    try {
      const init = withAuth();
      const res = await fetch(apiUrl(`/api/targets/${editingId}`), {
        ...init,
        method: "PUT",
        headers: { "Content-Type": "application/json", ...(init as any).headers },
        body: JSON.stringify(editTarget),
      });
      const j = await res.json();
      if (!res.ok) throw new Error(j?.error || "更新失败");
      toast.success("已更新目标服务器");
      cancelEdit();
      // reload current page
      setPage(page);
    } catch (e: any) {
      toast.error(e?.message || "更新失败");
    } finally {
      setSavingEdit(false);
    }
  };

  const deleteTarget = (id: number) => {
    setPendingDeleteId(id);
    setConfirmOpen(true);
  };

  const handleConfirmDelete = async () => {
    if (!pendingDeleteId) return;
    setDeletingId(pendingDeleteId);
    try {
      const res = await fetch(apiUrl(`/api/targets/${pendingDeleteId}`), { ...withAuth(), method: "DELETE" });
      const j = await res.json();
      if (!res.ok) throw new Error(j?.error || "删除失败（需要管理员权限）");
      toast.success("已删除");
      // reload list
      setPage(1);
    } catch (e: any) {
      toast.error(e?.message || "删除失败");
    } finally {
      setDeletingId(null);
      setConfirmOpen(false);
      setPendingDeleteId(null);
    }
  };

  // simple batch ssh test for multiple hosts using current newTarget creds
  const batchTest = async (hostsCsv: string, opts?: { timeoutMs?: number; retries?: number; concurrency?: number }) => {
    const hosts = hostsCsv.split(/[,\n\s]+/).map(h => h.trim()).filter(Boolean);
    if (hosts.length === 0) {
      toast.error("请填写至少一个主机");
      return;
    }
    const payload = {
      targets: hosts.map(h => ({
        host: h,
        ssh_user: newTarget.ssh_user,
        ssh_port: newTarget.ssh_port,
        auth_type: newTarget.auth_type,
        password: newTarget.auth_type === "password" ? newTarget.password : undefined,
        private_key: newTarget.auth_type === "key" ? newTarget.private_key : undefined,
        passphrase: newTarget.auth_type === "key" ? newTarget.passphrase : undefined,
      })),
      timeoutMs: opts?.timeoutMs ?? 6000,
      retries: opts?.retries ?? 0,
      concurrency: opts?.concurrency ?? 5,
    };
    try {
      const res = await fetch(apiUrl("/api/targets/test-ssh"), {
        ...withAuth(),
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload),
      });
      const j = await res.json();
      if (!res.ok) throw new Error(j?.error || "批量测试失败");
      const ok = j?.summary?.success ?? 0;
      const fail = j?.summary?.failed ?? 0;
      toast.success(`批量测试完成：成功 ${ok}，失败 ${fail}`);
    } catch (e: any) {
      toast.error(e?.message || "批量测试失败");
    }
  };

  const totalPages = Math.max(1, Math.ceil(total / pageSize));

  // auto refresh fs & processes when switching target
  useEffect(() => {
    if (targetId) {
      refreshFs();
      refreshProcs();
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [targetId]);

  // 新增：将选择持久化到本地
  useEffect(() => {
    if (selSystemId) localStorage.setItem(LS_KEYS.system, selSystemId);
  }, [selSystemId]);
  useEffect(() => {
    if (selProjectId) localStorage.setItem(LS_KEYS.project, selProjectId);
  }, [selProjectId]);
  useEffect(() => {
    if (selPackageId) localStorage.setItem(LS_KEYS.pkg, selPackageId);
  }, [selPackageId]);
  useEffect(() => {
    if (targetId) localStorage.setItem(LS_KEYS.target, targetId);
  }, [targetId]);

  // 新增：根据环境筛选校验当前 targetId
  useEffect(() => {
    const list = targets.filter((t) => (filterEnv ? t.env === filterEnv : true));
    const exists = list.some((t) => String(t.id) === String(targetId));
    if (!exists && list.length > 0) {
      setTargetId(String(list[0].id));
    }
    // 如果过滤后为空，则清空选中，避免误用
    if (list.length === 0) {
      setTargetId("");
    }
  }, [filterEnv, targets]);

  // 计算：按环境过滤后的目标列表
  const filteredTargets = targets.filter((t) => (filterEnv ? t.env === filterEnv : true));

  return (
    <div className="mx-auto max-w-6xl px-6 py-10 space-y-8">
      <h1 className="text-2xl font-semibold">部署与服务器监控</h1>

      {/* 新增：系统-项目-成品包 选择卡片 */}
      <Card>
        <CardHeader>
          <div className="flex items-center justify-between gap-3">
            <CardTitle>发布选择（系统 → 项目 → 成品包）</CardTitle>
            <Link href="/deployments/history" className="text-sm text-muted-foreground hover:underline">查看发布历史</Link>
          </div>
        </CardHeader>
        <CardContent className="grid gap-4">
          <div className="grid gap-4 sm:grid-cols-3">
            <div className="space-y-2">
              <Label>系统</Label>
              <Select
                value={selSystemId}
                onValueChange={(v) => {
                  setSelSystemId(v);
                  setSelProjectId("");
                  setSelPackageId("");
                  setPkgList([]);
                }}
                disabled={loadingCascade}
              >
                <SelectTrigger>
                  <SelectValue placeholder={loadingCascade ? "加载中..." : "请选择系统"} />
                </SelectTrigger>
                <SelectContent>
                  {systems.map((s) => (
                    <SelectItem key={s.id} value={String(s.id)}>
                      {s.name}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>

            <div className="space-y-2">
              <Label>项目</Label>
              <Select
                value={selProjectId}
                onValueChange={(v) => {
                  setSelProjectId(v);
                  setSelPackageId("");
                }}
                disabled={!selSystemId || loadingCascade}
              >
                <SelectTrigger>
                  <SelectValue placeholder={!selSystemId ? "先选择系统" : "请选择项目"} />
                </SelectTrigger>
                <SelectContent>
                  {projList
                    .filter((p) => p.system_id === Number(selSystemId))
                    .map((p) => (
                      <SelectItem key={p.id} value={String(p.id)}>
                        {p.name}
                      </SelectItem>
                    ))}
                </SelectContent>
              </Select>
            </div>

            <div className="space-y-2">
              <Label>成品包</Label>
              <Select
                value={selPackageId}
                onValueChange={setSelPackageId}
                disabled={!selProjectId || loadingPkgs}
              >
                <SelectTrigger>
                  <SelectValue placeholder={!selProjectId ? "先选择项目" : loadingPkgs ? "加载中..." : "请选择成品包"} />
                </SelectTrigger>
                <SelectContent>
                  {pkgList.map((pkg: any) => (
                    <SelectItem key={pkg.id} value={String(pkg.id)}>
                      {pkg.name}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
          </div>

          <div className="flex justify-end">
            <Button
              onClick={async () => {
                if (!selSystemId || !selProjectId || !selPackageId) return;
                if (!targetId) { toast.error("请选择目标服务器"); return; }
                try {
                  // 发布前 SSH 预检（使用已存凭据，通过目标ID在服务端校验）
                  const pre = await fetch(
                    apiUrl("/api/targets/test-connection"),
                    { ...withAuth(), method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ id: Number(targetId), timeoutMs: 6000 }) }
                  );
                  const pj = await pre.json();
                  if (!pre.ok || !pj?.ok) throw new Error(pj?.error || "SSH 预检失败");
                  if (typeof pj?.latencyMs === "number") {
                    toast.success(`SSH 预检通过，用时 ${pj.latencyMs}ms`);
                  } else {
                    toast.success("SSH 预检通过");
                  }
                } catch (e: any) {
                  toast.error(e?.message || "SSH 预检失败");
                  return;
                }

                setPublishing(true);
                setDeploySteps([]);
                try {
                  const init = withAuth();
                  const payload = {
                    systemId: Number(selSystemId) || null,
                    projectId: Number(selProjectId),
                    packageId: Number(selPackageId),
                    targetId: Number(targetId),
                  };
                  const res = await fetch(
                    apiUrl("/api/deployments"),
                    { ...init, method: "POST", headers: { "Content-Type": "application/json", ...(init as any).headers }, body: JSON.stringify(payload) }
                  );
                  const j = await res.json();
                  if (!res.ok || !j?.ok) throw new Error(j?.error || "发布失败");
                  setDeploySteps(Array.isArray(j.steps) ? j.steps : []);
                  setLastDeploymentId(j.deploymentId ?? null);
                  const sys = systems.find((s) => String(s.id) === selSystemId)?.name || "";
                  const proj = projList.find((p) => String(p.id) === selProjectId)?.name || "";
                  const pkg = pkgList.find((k: any) => String(k.id) === selPackageId)?.name || "";
                  toast.success(`发布完成（ID: ${j.deploymentId}）：${sys} / ${proj} / ${pkg}`);
                  // 发布后自动刷新 进程 与 目录
                  await refreshProcs();
                  await refreshFs();
                } catch (e: any) {
                  toast.error(e?.message || "发布失败");
                } finally {
                  setPublishing(false);
                }
              }}
              disabled={!selSystemId || !selProjectId || !selPackageId || !targetId || publishing}
            >
              {publishing ? "发布中..." : "继续发布"}
            </Button>
          </div>

          {/* 新增：发布进度与步骤日志 */}
          {publishing || deploySteps.length > 0 ? (
            <div className="mt-2 border-t pt-4">
              <div className="flex items-center justify-between mb-2">
                <div className="text-sm text-muted-foreground">
                  发布{publishing ? "进行中" : "完成"}{lastDeploymentId ? ` · ID #${lastDeploymentId}` : ""}
                </div>
                <Link href="/deployments/history" className="text-sm hover:underline">查看历史</Link>
              </div>
              <ul className="space-y-2">
                {(deploySteps.length ? deploySteps : [
                  { key: "validate", label: "校验参数", ok: true },
                  { key: "connect", label: `连接目标服务器 #${targetId}` , ok: true },
                  { key: "upload", label: `上传成品包 ${selPackageId}`, ok: true },
                  { key: "deploy", label: `部署项目 ${selProjectId} 到目标 ${targetId}`, ok: true },
                  { key: "verify", label: "部署验证", ok: true },
                ]).map((s) => (
                  <li key={s.key} className="flex items-center gap-2">
                    <span className={`h-2 w-2 rounded-full ${s.ok ? "bg-emerald-500" : "bg-destructive"}`} />
                    <span className="text-sm">{s.label}</span>
                    <span className={`ml-auto text-xs ${s.ok ? "text-emerald-600" : "text-destructive"}`}>{s.ok ? "OK" : "FAILED"}</span>
                  </li>
                ))}
              </ul>
            </div>
          ) : null}
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>新增目标服务器</CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
            <div className="space-y-2">
              <Label htmlFor="name">名称</Label>
              <Input id="name" value={newTarget.name} onChange={(e) => setNewTarget({ ...newTarget, name: e.target.value })} placeholder="如：生产A" />
            </div>
            <div className="space-y-2">
              <Label htmlFor="host">主机(host)</Label>
              <Input id="host" value={newTarget.host} onChange={(e) => setNewTarget({ ...newTarget, host: e.target.value })} placeholder="如：192.168.1.10" />
            </div>
            <div className="space-y-2">
              <Label htmlFor="env">环境</Label>
              <Select value={newTarget.env} onValueChange={(v) => setNewTarget({ ...newTarget, env: v as any })}>
                <SelectTrigger id="env">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="dev">开发(dev)</SelectItem>
                  <SelectItem value="staging">预发(staging)</SelectItem>
                  <SelectItem value="prod">生产(prod)</SelectItem>
                </SelectContent>
              </Select>
            </div>
            <div className="space-y-2">
              <Label htmlFor="ssh_user">SSH 用户</Label>
              <Input id="ssh_user" value={newTarget.ssh_user} onChange={(e) => setNewTarget({ ...newTarget, ssh_user: e.target.value })} />
            </div>
            <div className="space-y-2">
              <Label htmlFor="ssh_port">SSH 端口</Label>
              <Input id="ssh_port" type="number" value={newTarget.ssh_port} onChange={(e) => setNewTarget({ ...newTarget, ssh_port: Number(e.target.value) })} />
            </div>
            <div className="space-y-2 lg:col-span-2">
              <Label htmlFor="root_path">根目录</Label>
              <Input id="root_path" value={newTarget.root_path} onChange={(e) => setNewTarget({ ...newTarget, root_path: e.target.value })} />
            </div>
            <div className="space-y-2 lg:col-span-1">
              <Label className="flex items-center gap-2">
                <input
                  type="checkbox"
                  className="accent-foreground"
                  checked={newTarget.options.storeCredentials}
                  onChange={(e) => setNewTarget({ ...newTarget, options: { ...newTarget.options, storeCredentials: e.target.checked } })}
                />
                保存凭据到数据库（取消勾选仅用于测试，不入库）
              </Label>
            </div>
          </div>

          {/* Auth section */}
          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
            <div className="space-y-2">
              <Label htmlFor="auth_type">认证方式</Label>
              <Select value={newTarget.auth_type} onValueChange={(v) => setNewTarget({ ...newTarget, auth_type: v as any })}>
                <SelectTrigger id="auth_type">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="password">口令（Password）</SelectItem>
                  <SelectItem value="key">私钥（Private Key）</SelectItem>
                </SelectContent>
              </Select>
            </div>
            {newTarget.auth_type === "password" ? (
              <div className="space-y-2">
                <Label htmlFor="password">口令（可留空）</Label>
                <Input id="password" type="password" autoComplete="off" value={newTarget.password} onChange={(e) => setNewTarget({ ...newTarget, password: e.target.value })} />
              </div>
            ) : (
              <>
                <div className="space-y-2 lg:col-span-2">
                  <Label htmlFor="private_key">私钥（粘贴内容或上传）</Label>
                  <textarea id="private_key" className="w-full rounded-md border border-input bg-background px-3 py-2 text-sm min-h-28" value={newTarget.private_key} onChange={(e) => setNewTarget({ ...newTarget, private_key: e.target.value })} placeholder="-----BEGIN OPENSSH PRIVATE KEY-----\n...\n-----END OPENSSH PRIVATE KEY-----" />
                  <div className="pt-2">
                    <input id="private_key_file" type="file" accept=".pem,.key,.txt" onChange={(e) => handleKeyUpload(e.target.files?.[0])} />
                  </div>
                </div>
                <div className="space-y-2">
                  <Label htmlFor="passphrase">私钥口令（可选）</Label>
                  <Input id="passphrase" type="password" autoComplete="off" value={newTarget.passphrase} onChange={(e) => setNewTarget({ ...newTarget, passphrase: e.target.value })} />
                </div>
              </>
            )}
          </div>

          <div className="flex flex-wrap gap-3 justify-end">
            <Button type="button" variant="secondary" onClick={testConnection} disabled={loadingTest}>
              {loadingTest ? "测试中..." : "测试连接"}
            </Button>
            <Button type="button" onClick={createTarget} disabled={loadingCreate}>
              {loadingCreate ? "保存中..." : "保存服务器"}
            </Button>
          </div>

          {/* 简易批量测试：使用上面认证，对多主机进行并发测试 */}
          <div className="space-y-3">
            <Label htmlFor="hosts_batch">批量测试（以逗号/空格/换行分隔主机）</Label>
            <textarea
              id="hosts_batch"
              className="w-full rounded-md border border-input bg-background px-3 py-2 text-sm min-h-24"
              placeholder="192.168.1.10, 192.168.1.11\nexample.com"
              value={batchHosts}
              onChange={(e) => setBatchHosts(e.target.value)}
            />
            <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
              <div className="space-y-1">
                <Label>超时(ms)</Label>
                <Input type="number" value={batchOpts.timeoutMs}
                  onChange={(e) => setBatchOpts({ ...batchOpts, timeoutMs: Math.max(1000, Number(e.target.value || 0)) })} />
              </div>
              <div className="space-y-1">
                <Label>重试次数</Label>
                <Input type="number" value={batchOpts.retries}
                  onChange={(e) => setBatchOpts({ ...batchOpts, retries: Math.max(0, Number(e.target.value || 0)) })} />
              </div>
              <div className="space-y-1">
                <Label>并发数</Label>
                <Input type="number" value={batchOpts.concurrency}
                  onChange={(e) => setBatchOpts({ ...batchOpts, concurrency: Math.min(10, Math.max(1, Number(e.target.value || 1))) })} />
              </div>
            </div>
            <div className="flex gap-2 justify-end">
              <Button type="button" variant="secondary" disabled={batchLoading} onClick={async () => {
                const hosts = batchHosts.split(/[\,\n\s]+/).map(h => h.trim()).filter(Boolean);
                if (hosts.length === 0) { toast.error("请填写至少一个主机"); return; }
                setBatchLoading(true);
                try {
                  const payload = {
                    targets: hosts.map(h => ({
                      host: h,
                      ssh_user: newTarget.ssh_user,
                      ssh_port: newTarget.ssh_port,
                      auth_type: newTarget.auth_type,
                      password: newTarget.auth_type === "password" ? newTarget.password : undefined,
                      private_key: newTarget.auth_type === "key" ? newTarget.private_key : undefined,
                      passphrase: newTarget.auth_type === "key" ? newTarget.passphrase : undefined,
                    })),
                    timeoutMs: batchOpts.timeoutMs,
                    retries: batchOpts.retries,
                    concurrency: batchOpts.concurrency,
                  };
                  const res = await fetch(apiUrl("/api/targets/test-ssh"), {
                    ...withAuth(),
                    method: "POST",
                    headers: { "Content-Type": "application/json" },
                    body: JSON.stringify(payload),
                  });
                  const j = await res.json();
                  if (!res.ok) throw new Error(j?.error || "批量测试失败");
                  const results = Array.isArray(j.results) ? j.results : [];
                  setBatchResults(results);
                  const ok = j?.summary?.success ?? results.filter((r: any) => r.ok).length;
                  const fail = j?.summary?.failed ?? results.filter((r: any) => !r.ok).length;
                  toast.success(`批量测试完成：成功 ${ok}，失败 ${fail}`);
                } catch (e: any) {
                  toast.error(e?.message || "批量测试失败");
                } finally {
                  setBatchLoading(false);
                }
              }}>
                {batchLoading ? "测试中..." : "开始批量测试"}
              </Button>
            </div>
            {batchResults.length > 0 && (
              <div className="overflow-x-auto">
                <Table>
                  <TableHeader>
                    <TableRow>
                      <TableHead>主机</TableHead>
                      <TableHead>结果</TableHead>
                      <TableHead>耗时(ms)</TableHead>
                      <TableHead>错误</TableHead>
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {batchResults.map((r, idx) => (
                      <TableRow key={`${r.host}-${idx}`}>
                        <TableCell className="font-medium">{r.host}</TableCell>
                        <TableCell>{r.ok ? "成功" : "失败"}</TableCell>
                        <TableCell>{r.latencyMs ?? "-"}</TableCell>
                        <TableCell className="max-w-[380px] truncate" title={r.error || ""}>{r.error || "-"}</TableCell>
                      </TableRow>
                    ))}
                  </TableBody>
                </Table>
              </div>
            )}
            <p className="text-xs text-muted-foreground">支持并发、重试与超时设置；详细错误在表格中展示。</p>
          </div>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>目标服务器列表</CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="flex flex-col sm:flex-row gap-3 sm:items-end">
            <div className="flex-1 space-y-2">
              <Label htmlFor="search">搜索</Label>
              <Input id="search" placeholder="按名称或主机搜索" value={q} onChange={(e) => { setQ(e.target.value); setPage(1); }} />
            </div>
            {/* 新增：环境筛选 */}
            <div className="space-y-2 w-full sm:w-40">
              <Label htmlFor="env_filter">环境筛选</Label>
              <Select value={filterEnv || "__all__"} onValueChange={(v) => setFilterEnv(v === "__all__" ? "" : v)}>
                <SelectTrigger id="env_filter">
                  <SelectValue placeholder="全部" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="__all__">全部</SelectItem>
                  <SelectItem value="dev">dev</SelectItem>
                  <SelectItem value="staging">staging</SelectItem>
                  <SelectItem value="prod">prod</SelectItem>
                </SelectContent>
              </Select>
            </div>
            <div className="flex items-end gap-2">
              <Button variant="secondary" onClick={() => setPage(1)} disabled={loadingTargets}>查询</Button>
              <div className="flex items-center gap-2">
                <Button variant="ghost" disabled={page<=1 || loadingTargets} onClick={() => setPage((p) => Math.max(1, p-1))}>上一页</Button>
                <span className="text-sm text-muted-foreground">{page} / {totalPages}</span>
                <Button variant="ghost" disabled={page>=totalPages || loadingTargets} onClick={() => setPage((p) => Math.min(totalPages, p+1))}>下一页</Button>
              </div>
            </div>
          </div>

          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>名称</TableHead>
                <TableHead>主机</TableHead>
                <TableHead>用户</TableHead>
                <TableHead>端口</TableHead>
                <TableHead>环境</TableHead>
                <TableHead>凭据</TableHead>
                <TableHead className="text-right">操作</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {filteredTargets.map((t) => (
                <TableRow key={t.id}>
                  <TableCell className="font-medium">{t.name}</TableCell>
                  <TableCell>{t.host}</TableCell>
                  <TableCell>{t.sshUser}</TableCell>
                  <TableCell>{t.sshPort}</TableCell>
                  <TableCell>{t.env || "-"}</TableCell>
                  <TableCell>{t.hasPrivateKey ? "私钥" : t.hasPassword ? "口令" : "无"}</TableCell>
                  <TableCell className="text-right space-x-2">
                    <Button size="sm" variant="secondary" onClick={() => startEdit(t)}>编辑</Button>
                    <Button size="sm" variant="ghost" onClick={() => setTargetId(String(t.id))}>选择</Button>
                    <Button size="sm" variant="destructive" onClick={() => deleteTarget(t.id)} disabled={deletingId === t.id}>{deletingId === t.id ? "删除中" : "删除"}</Button>
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>

          {editingId && editTarget && (
            <div className="mt-6 border rounded-md p-4 space-y-4">
              <div className="text-sm font-medium">编辑目标（ID: {editingId}）</div>
              <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
                <div className="space-y-2">
                  <Label>名称</Label>
                  <Input value={editTarget.name} onChange={(e) => setEditTarget({ ...editTarget, name: e.target.value })} />
                </div>
                <div className="space-y-2">
                  <Label>主机</Label>
                  <Input value={editTarget.host} onChange={(e) => setEditTarget({ ...editTarget, host: e.target.value })} />
                </div>
                <div className="space-y-2">
                  <Label>环境</Label>
                  <Select value={editTarget.env} onValueChange={(v) => setEditTarget({ ...editTarget, env: v })}>
                    <SelectTrigger>
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="dev">dev</SelectItem>
                      <SelectItem value="staging">staging</SelectItem>
                      <SelectItem value="prod">prod</SelectItem>
                    </SelectContent>
                  </Select>
                </div>
                <div className="space-y-2">
                  <Label>SSH 用户</Label>
                  <Input value={editTarget.ssh_user} onChange={(e) => setEditTarget({ ...editTarget, ssh_user: e.target.value })} />
                </div>
                <div className="space-y-2">
                  <Label>SSH 端口</Label>
                  <Input type="number" value={editTarget.ssh_port} onChange={(e) => setEditTarget({ ...editTarget, ssh_port: Number(e.target.value) })} />
                </div>
                <div className="space-y-2 lg:col-span-2">
                  <Label>根目录</Label>
                  <Input value={editTarget.root_path} onChange={(e) => setEditTarget({ ...editTarget, root_path: e.target.value })} />
                </div>
                <div className="space-y-2">
                  <Label>认证方式</Label>
                  <Select value={editTarget.auth_type} onValueChange={(v) => setEditTarget({ ...editTarget, auth_type: v })}>
                    <SelectTrigger>
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="password">password</SelectItem>
                      <SelectItem value="key">key</SelectItem>
                    </SelectContent>
                  </Select>
                </div>
                {editTarget.auth_type === "password" ? (
                  <div className="space-y-2">
                    <Label>口令（留空不变，清空以删除）</Label>
                    <Input type="password" autoComplete="off" value={editTarget.password} onChange={(e) => setEditTarget({ ...editTarget, password: e.target.value })} />
                  </div>
                ) : (
                  <>
                    <div className="space-y-2 lg:col-span-2">
                      <Label>私钥（留空不变，清空以删除）</Label>
                      <textarea className="w-full rounded-md border border-input bg-background px-3 py-2 text-sm min-h-28" value={editTarget.private_key} onChange={(e) => setEditTarget({ ...editTarget, private_key: e.target.value })} />
                    </div>
                    <div className="space-y-2">
                      <Label>私钥口令（留空不变，清空以删除）</Label>
                      <Input type="password" autoComplete="off" value={editTarget.passphrase} onChange={(e) => setEditTarget({ ...editTarget, passphrase: e.target.value })} />
                    </div>
                  </>
                )}
              </div>
              <div className="flex gap-2 justify-end">
                <Button variant="ghost" onClick={cancelEdit}>取消</Button>
                <Button onClick={saveEdit} disabled={savingEdit}>{savingEdit ? "保存中..." : "保存修改"}</Button>
              </div>
            </div>
          )}
        </CardContent>
      </Card>

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
                  {filteredTargets.map((t) => (
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
                  <TableCell>{d.type === "dir" ? "目录" : d.type === "file" ? "文件" : d.type}</TableCell>
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

      {/* 删除确认对话框 */}
      <AlertDialog open={confirmOpen} onOpenChange={setConfirmOpen}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>确认删除该目标服务器？</AlertDialogTitle>
            <AlertDialogDescription>
              删除后将无法恢复，相关目录与进程配置不会自动清理，请谨慎操作。
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>取消</AlertDialogCancel>
            <AlertDialogAction onClick={handleConfirmDelete} disabled={deletingId !== null}>
              {deletingId !== null ? "删除中..." : "确认删除"}
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </div>
  );
}
"use client";

import { useEffect, useMemo, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { Separator } from "@/components/ui/separator";
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

export function DeployDetailsClient({ id }: { id: number }) {
  const router = useRouter();
  const [loading, setLoading] = useState(true);
  const [acting, setActing] = useState<string | null>(null);
  const [items, setItems] = useState<DeploymentItem[]>([]);
  const item = useMemo(() => items.find((x) => x.id === id) || null, [items, id]);

  // Controls form state
  const [mode, setMode] = useState<"nohup" | "sh">("nohup");
  const [workdir, setWorkdir] = useState("");
  const [jarPath, setJarPath] = useState("");
  const [javaOpts, setJavaOpts] = useState("");
  const [envText, setEnvText] = useState(""); // JSON string
  const [startScript, setStartScript] = useState("");
  const [logFile, setLogFile] = useState("");
  const [stopPid, setStopPid] = useState("");
  const [stopPattern, setStopPattern] = useState("");
  const [logsPreview, setLogsPreview] = useState("");

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
  }, [id]);

  useEffect(() => {
    if (item) {
      // Prefill reasonable defaults from steps if available
      const guessWorkdir = item.steps.find((s) => /工作目录|workdir/i.test(s.label));
      if (guessWorkdir) setWorkdir((prev) => prev || "/opt/apps/current");
      setLogFile((prev) => prev || `${"/opt/apps/current"}/logs/app.out`);
    }
  }, [item]);

  const parseEnv = () => {
    if (!envText.trim()) return {} as Record<string, string>;
    try {
      return JSON.parse(envText);
    } catch {
      toast.error("环境变量需为 JSON 对象，例如 {\"JAVA_HOME\":\"/usr/java\"}");
      throw new Error("bad env json");
    }
  };

  const doStart = async () => {
    setActing("start");
    try {
      const body: any = { mode, target_id: item?.targetId, workdir, log_file: logFile };
      if (mode === "nohup") {
        if (!workdir || !jarPath) throw new Error("请填写工作目录与 JAR 路径");
        body.jar_path = jarPath;
        body.java_opts = javaOpts;
        if (envText.trim()) body.env = parseEnv();
      } else {
        if (!workdir || !startScript) throw new Error("请填写工作目录与启动脚本");
        body.start_script = startScript;
        if (envText.trim()) body.env = parseEnv();
      }
      const res = await fetch(apiUrl("/api/control/start"), { ...withAuth(), method: "POST", body: JSON.stringify(body) });
      const j = await res.json();
      if (!res.ok) throw new Error(j?.error || "启动失败");
      toast.success(`启动成功 (PID: ${j?.pid ?? "?"})`);
    } catch (e: any) {
      toast.error(e?.message || "启动失败");
    } finally {
      setActing(null);
    }
  };

  const doStop = async () => {
    setActing("stop");
    try {
      const body: any = { target_id: item?.targetId };
      if (stopPid) body.pid = Number(stopPid);
      if (stopPattern) body.pattern = stopPattern;
      if (!body.pid && !body.pattern) throw new Error("请填写 PID 或进程特征");
      const res = await fetch(apiUrl("/api/control/stop"), { ...withAuth(), method: "POST", body: JSON.stringify(body) });
      const j = await res.json();
      if (!res.ok) throw new Error(j?.error || "停止失败");
      toast.success("停止成功");
    } catch (e: any) {
      toast.error(e?.message || "停止失败");
    } finally {
      setActing(null);
    }
  };

  const doRestart = async () => {
    setActing("restart");
    try {
      await doStop();
      await doStart();
      toast.success("重启完成");
    } finally {
      setActing(null);
    }
  };

  const doLogs = async () => {
    setActing("logs");
    try {
      if (!logFile) throw new Error("请填写日志文件路径");
      const res = await fetch(apiUrl("/api/control/logs"), { ...withAuth(), method: "POST", body: JSON.stringify({
        target_id: item?.targetId,
        file: logFile,
        tail: 200,
      }) });
      const j = await res.json();
      if (!res.ok) throw new Error(j?.error || "获取日志失败");
      setLogsPreview(j?.content || "");
    } catch (e: any) {
      setLogsPreview("");
      toast.error(e?.message || "获取日志失败");
    } finally {
      setActing(null);
    }
  };

  const doRollback = async () => {
    if (!item) return;
    setActing("rollback");
    try {
      const res = await fetch(apiUrl(`/api/deployments/${item.id}/rollback`), { ...withAuth(), method: "POST" });
      const j = await res.json();
      if (!res.ok || !j?.ok) throw new Error(j?.error || "回滚失败");
      toast.success("回滚成功");
      await load();
      router.push("/deployments/history");
    } catch (e: any) {
      toast.error(e?.message || "回滚失败");
    } finally {
      setActing(null);
    }
  };

  return (
    <div className="mx-auto max-w-6xl px-6 py-10 space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-semibold">发布详情 #{id}</h1>
        <div className="flex items-center gap-2 text-sm">
          <Link href="/deployments/history" className="text-muted-foreground hover:underline">返回历史</Link>
          <Button variant="outline" size="sm" onClick={load} disabled={loading}>{loading ? "刷新中…" : "刷新"}</Button>
        </div>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>基本信息</CardTitle>
        </CardHeader>
        <CardContent className="space-y-2 text-sm">
          {!item && !loading && (
            <p className="text-muted-foreground">未找到该发布记录，可能已被清空。</p>
          )}
          {item && (
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
              <div>发布ID：<span className="font-mono">{item.id}</span></div>
              <div>系统：{item.systemId ?? "-"}</div>
              <div>项目：{item.projectId}</div>
              <div>成品包：{item.packageId}</div>
              <div>目标机：{item.targetId}</div>
              <div>开始时间：{new Date(item.startedAt).toLocaleString()}</div>
              <div>状态：<span className={`inline-flex items-center rounded px-2 py-0.5 text-xs ${
                item.status === "success"
                  ? "bg-emerald-100 text-emerald-700 dark:bg-emerald-900/30 dark:text-emerald-300"
                  : item.status === "rolledback"
                  ? "bg-amber-100 text-amber-700 dark:bg-amber-900/30 dark:text-amber-300"
                  : "bg-destructive/10 text-destructive"
              }`}>{item.status === "success" ? "成功" : item.status === "rolledback" ? "已回滚" : "失败"}</span></div>
            </div>
          )}
          {item && (
            <div className="mt-4">
              <p className="font-medium mb-2">步骤</p>
              <ul className="space-y-2">
                {item.steps.map((s) => (
                  <li key={s.key} className="flex items-center gap-2">
                    <span className={`h-2 w-2 rounded-full ${s.ok ? "bg-emerald-500" : "bg-destructive"}`} />
                    <span className="text-sm">{s.label}</span>
                    <span className={`ml-auto text-xs ${s.ok ? "text-emerald-600" : "text-destructive"}`}>{s.ok ? "OK" : "FAILED"}</span>
                  </li>
                ))}
              </ul>
            </div>
          )}
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>应用控制</CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div className="space-y-3">
              <div className="grid grid-cols-3 items-center gap-2">
                <Label className="col-span-1 text-sm">模式</Label>
                <div className="col-span-2 flex gap-2">
                  <Button type="button" variant={mode === "nohup" ? "default" : "outline"} size="sm" onClick={() => setMode("nohup")}>nohup</Button>
                  <Button type="button" variant={mode === "sh" ? "default" : "outline"} size="sm" onClick={() => setMode("sh")}>sh</Button>
                </div>
              </div>
              <div className="grid grid-cols-3 items-center gap-2">
                <Label className="col-span-1 text-sm">工作目录</Label>
                <Input className="col-span-2" value={workdir} onChange={(e) => setWorkdir(e.target.value)} placeholder="/opt/apps/current" />
              </div>
              {mode === "nohup" ? (
                <>
                  <div className="grid grid-cols-3 items-center gap-2">
                    <Label className="col-span-1 text-sm">JAR路径</Label>
                    <Input className="col-span-2" value={jarPath} onChange={(e) => setJarPath(e.target.value)} placeholder="/opt/apps/releases/xxx/app.jar" />
                  </div>
                  <div className="grid grid-cols-3 items-center gap-2">
                    <Label className="col-span-1 text-sm">Java参数</Label>
                    <Input className="col-span-2" value={javaOpts} onChange={(e) => setJavaOpts(e.target.value)} placeholder="-Xms512m -Xmx1024m" />
                  </div>
                </>
              ) : (
                <div className="grid grid-cols-3 items-center gap-2">
                  <Label className="col-span-1 text-sm">启动脚本</Label>
                  <Input className="col-span-2" value={startScript} onChange={(e) => setStartScript(e.target.value)} placeholder="./bin/start.sh" />
                </div>
              )}
              <div className="grid grid-cols-3 items-center gap-2">
                <Label className="col-span-1 text-sm">日志文件</Label>
                <Input className="col-span-2" value={logFile} onChange={(e) => setLogFile(e.target.value)} placeholder="/opt/apps/current/logs/app.out" />
              </div>
              <div className="grid grid-cols-3 items-start gap-2">
                <Label className="col-span-1 text-sm">环境变量(JSON)</Label>
                <Textarea className="col-span-2" rows={3} value={envText} onChange={(e) => setEnvText(e.target.value)} placeholder='{"JAVA_HOME":"/usr/lib/jvm/java-17"}' />
              </div>
              <div className="flex gap-2">
                <Button onClick={doStart} disabled={acting !== null}>{acting === "start" ? "启动中…" : "启动"}</Button>
                <Button onClick={doRestart} variant="secondary" disabled={acting !== null}>{acting === "restart" ? "重启中…" : "重启"}</Button>
              </div>
            </div>

            <div className="space-y-3">
              <div className="grid grid-cols-3 items-center gap-2">
                <Label className="col-span-1 text-sm">停止PID</Label>
                <Input className="col-span-2" value={stopPid} onChange={(e) => setStopPid(e.target.value)} placeholder="12345" />
              </div>
              <div className="grid grid-cols-3 items-center gap-2">
                <Label className="col-span-1 text-sm">或匹配字符</Label>
                <Input className="col-span-2" value={stopPattern} onChange={(e) => setStopPattern(e.target.value)} placeholder="java -jar app.jar" />
              </div>
              <div className="flex gap-2">
                <Button variant="destructive" onClick={doStop} disabled={acting !== null}>{acting === "stop" ? "停止中…" : "停止"}</Button>
                <Button variant="outline" onClick={doLogs} disabled={acting !== null}>{acting === "logs" ? "拉取中…" : "查看日志"}</Button>
              </div>
              <Separator />
              <div>
                <Label className="mb-1 block text-sm">日志预览</Label>
                <Textarea readOnly rows={12} value={logsPreview} placeholder="点击“查看日志”以拉取当前日志..." />
              </div>
            </div>
          </div>
        </CardContent>
      </Card>

      <div className="flex items-center justify-between">
        <div className="text-xs text-muted-foreground">以上操作通过后端控制 API 实现，需确保目标机可达且凭据正确。</div>
        <div className="flex gap-2">
          <Button variant="outline" onClick={() => router.push("/deployments/history")}>返回历史</Button>
          <Button onClick={doRollback} disabled={acting !== null}>{acting === "rollback" ? "回滚中…" : "回滚此版本"}</Button>
        </div>
      </div>
    </div>
  );
}
"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { toast } from "sonner";
import { apiUrl, withAuth } from "@/lib/api";

export default function ControlPage() {
  const [appName, setAppName] = useState("demo-app");
  const [jarPath, setJarPath] = useState("/opt/apps/demo-app/app.jar");
  const [workdir, setWorkdir] = useState("/opt/apps/demo-app");
  const [port, setPort] = useState("8080");
  const [logFile, setLogFile] = useState("/opt/apps/demo-app/app.out");
  const [javaOpts, setJavaOpts] = useState("-Xms512m -Xmx1024m");
  const [env, setEnv] = useState(`JAVA_HOME=/usr/lib/jvm/java-17\nSPRING_PROFILES_ACTIVE=prod`);
  const [status, setStatus] = useState<"stopped" | "running" | "unknown">("stopped");
  const [jdk, setJdk] = useState("java17");
  const [loadingStart, setLoadingStart] = useState(false);
  const [loadingStop, setLoadingStop] = useState(false);
  const [currentPid, setCurrentPid] = useState<number | null>(null);
  // Live log viewer state
  const [logStreaming, setLogStreaming] = useState(false);
  const [logText, setLogText] = useState("");
  const [autoScroll, setAutoScroll] = useState(true);
  const abortRef = useRef<AbortController | null>(null);
  const logBoxRef = useRef<HTMLDivElement | null>(null);

  const nohupCmd = useMemo(() => {
    const envInline = env
      .split("\n")
      .map((l) => l.trim())
      .filter(Boolean)
      .join(" ");
    const javaBin = jdk === "java8" ? "/usr/bin/java" : "/usr/bin/java"; // 示例占位
    return `cd ${workdir} && ${envInline} nohup ${javaBin} ${javaOpts} -jar ${jarPath} --server.port=${port} >> ${logFile} 2>&1 & echo $!`;
  }, [env, jdk, javaOpts, jarPath, port, workdir, logFile]);

  const [apps, setApps] = useState([
    { name: "demo-app", pid: 23124, port: 8080, status: "运行中" },
    { name: "report-service", pid: 0, port: 8090, status: "已停止" },
  ]);

  // API-integrated actions
  async function handleStart() {
    setLoadingStart(true);
    try {
      const res = await fetch(apiUrl("/api/control/start"), withAuth({
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          target_id: 1,
          workdir,
          jar_path: jarPath,
          java_opts: javaOpts,
          env: env
            .split("\n")
            .filter(Boolean)
            .reduce((acc: Record<string, string>, line) => {
              const [k, ...rest] = line.split("=");
              acc[k.trim()] = rest.join("=").trim();
              return acc;
            }, {}),
        }),
      }));
      const j = await res.json();
      if (!res.ok) throw new Error(j?.error || "启动失败");
      setStatus("running");
      setCurrentPid(j.pid);
      setLogFile(j.log_file || logFile);
      toast.success(`已启动，PID=${j.pid}`);
    } catch (e: any) {
      toast.error(e?.message || "启动失败");
    } finally {
      setLoadingStart(false);
    }
  }

  async function handleStop() {
    if (!currentPid) {
      toast.error("无有效 PID，无法停止");
      return;
    }
    setLoadingStop(true);
    try {
      const res = await fetch(apiUrl("/api/control/stop"), withAuth({
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ pid: currentPid }),
      }));
      const j = await res.json();
      if (!res.ok) throw new Error(j?.error || "停止失败");
      setStatus("stopped");
      toast.success("已停止");
    } catch (e: any) {
      toast.error(e?.message || "停止失败");
    } finally {
      setLoadingStop(false);
    }
  }

  async function handleRestart() {
    // 简单实现：先停后启
    if (currentPid) {
      await handleStop();
    }
    await new Promise((r) => setTimeout(r, 400));
    await handleStart();
  }

  // Logs: start streaming
  async function handleStartLogs() {
    if (logStreaming) return;
    try {
      setLogStreaming(true);
      const ac = new AbortController();
      abortRef.current = ac;
      const url = apiUrl(`/api/control/logs?path=${encodeURIComponent(logFile || "/var/log/app.log")}`);
      const res = await fetch(url, withAuth({
        method: "GET",
        headers: {},
        signal: ac.signal,
      }));
      if (!res.body) throw new Error("无法读取日志流");
      const reader = res.body.getReader();
      const decoder = new TextDecoder();
      const pump = async () => {
        while (true) {
          const { value, done } = await reader.read();
          if (done) break;
          const text = decoder.decode(value, { stream: true });
          setLogText((prev) => (prev.length > 200_000 ? prev.slice(-100_000) : prev) + text);
        }
      };
      pump().finally(() => {
        setLogStreaming(false);
      });
    } catch (e: any) {
      setLogStreaming(false);
      toast.error(e?.message || "日志连接失败");
    }
  }

  function handleStopLogs() {
    if (abortRef.current) {
      abortRef.current.abort();
      abortRef.current = null;
    }
    setLogStreaming(false);
  }

  function handleClearLogs() {
    setLogText("");
  }

  useEffect(() => {
    if (!autoScroll) return;
    const el = logBoxRef.current;
    if (el) {
      el.scrollTop = el.scrollHeight;
    }
  }, [logText, autoScroll]);

  return (
    <div className="mx-auto max-w-6xl px-6 py-10 space-y-8">
      <h1 className="text-2xl font-semibold">应用控制台（nohup 管理 Java）</h1>

      <Card>
        <CardHeader>
          <CardTitle>启动参数</CardTitle>
        </CardHeader>
        <CardContent className="space-y-6">
          <div className="grid gap-4 sm:grid-cols-2">
            <div className="space-y-2">
              <Label htmlFor="appName">应用名称</Label>
              <Input id="appName" value={appName} onChange={(e) => setAppName(e.target.value)} />
            </div>
            <div className="space-y-2">
              <Label htmlFor="jdk">JDK 版本</Label>
              <Select value={jdk} onValueChange={setJdk}>
                <SelectTrigger id="jdk">
                  <SelectValue placeholder="选择 JDK" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="java8">Java 8</SelectItem>
                  <SelectItem value="java11">Java 11</SelectItem>
                  <SelectItem value="java17">Java 17</SelectItem>
                </SelectContent>
              </Select>
            </div>
          </div>

          <div className="grid gap-4 sm:grid-cols-2">
            <div className="space-y-2">
              <Label htmlFor="jar">JAR 路径</Label>
              <Input id="jar" value={jarPath} onChange={(e) => setJarPath(e.target.value)} />
            </div>
            <div className="space-y-2">
              <Label htmlFor="workdir">工作目录</Label>
              <Input id="workdir" value={workdir} onChange={(e) => setWorkdir(e.target.value)} />
            </div>
          </div>

          <div className="grid gap-4 sm:grid-cols-3">
            <div className="space-y-2">
              <Label htmlFor="port">端口</Label>
              <Input id="port" value={port} onChange={(e) => setPort(e.target.value)} />
            </div>
            <div className="space-y-2 sm:col-span-2">
              <Label htmlFor="logfile">日志文件</Label>
              <Input id="logfile" value={logFile} onChange={(e) => setLogFile(e.target.value)} />
            </div>
          </div>

          <div className="space-y-2">
            <Label htmlFor="javaOpts">JVM 参数</Label>
            <Input id="javaOpts" value={javaOpts} onChange={(e) => setJavaOpts(e.target.value)} />
          </div>

          <div className="space-y-2">
            <Label htmlFor="env">环境变量（每行 KEY=VALUE）</Label>
            <Textarea id="env" rows={4} value={env} onChange={(e) => setEnv(e.target.value)} />
          </div>

          <div className="grid gap-3">
            <Label>生成的 nohup 启动命令（预览）</Label>
            <Textarea readOnly value={nohupCmd} rows={3} className="font-mono text-xs" />
          </div>

          <div className="flex flex-wrap items-center gap-3">
            <Button onClick={handleStart} disabled={loadingStart}>{loadingStart ? "启动中..." : "启动"}</Button>
            <Button variant="secondary" onClick={handleStop} disabled={loadingStop}>
              {loadingStop ? "停止中..." : "停止"}
            </Button>
            <Button variant="ghost" onClick={handleRestart}>重启</Button>
            <span className="text-sm text-muted-foreground">当前状态：{status === "running" ? "运行中" : status === "stopped" ? "已停止" : "未知"} {currentPid ? `(PID: ${currentPid})` : ""}</span>
          </div>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>受管应用列表</CardTitle>
        </CardHeader>
        <CardContent>
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>名称</TableHead>
                <TableHead>PID</TableHead>
                <TableHead>端口</TableHead>
                <TableHead>状态</TableHead>
                <TableHead>操作</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {apps.map((a) => (
                <TableRow key={a.name}>
                  <TableCell className="font-medium">{a.name}</TableCell>
                  <TableCell>{a.pid || "-"}</TableCell>
                  <TableCell>{a.port}</TableCell>
                  <TableCell>{a.status}</TableCell>
                  <TableCell className="space-x-2">
                    <Button size="sm" onClick={handleStart}>启动</Button>
                    <Button size="sm" variant="secondary" onClick={handleStop}>停止</Button>
                    <Button size="sm" variant="ghost" onClick={handleRestart}>重启</Button>
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>实时日志</CardTitle>
        </CardHeader>
        <CardContent className="space-y-3">
          <div className="flex flex-wrap items-center gap-2">
            <Button size="sm" onClick={handleStartLogs} disabled={logStreaming}> {logStreaming ? "连接中..." : "开始查看"} </Button>
            <Button size="sm" variant="secondary" onClick={handleStopLogs} disabled={!logStreaming}>停止查看</Button>
            <Button size="sm" variant="ghost" onClick={handleClearLogs}>清空</Button>
            <label className="flex items-center gap-2 text-sm text-muted-foreground">
              <input type="checkbox" checked={autoScroll} onChange={(e) => setAutoScroll(e.target.checked)} /> 自动滚动
            </label>
            <span className="text-xs text-muted-foreground">文件：{logFile || "/var/log/app.log"}</span>
          </div>
          <div
            ref={logBoxRef}
            className="h-72 w-full rounded-md border bg-card p-3 overflow-auto"
          >
            <pre className="text-xs leading-5 whitespace-pre-wrap break-words font-mono">{logText || "(尚无日志，点击“开始查看”)"}</pre>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
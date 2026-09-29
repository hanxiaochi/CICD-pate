import Link from "next/link";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Separator } from "@/components/ui/separator";
import { StatusBadge } from "@/components/app/status-badge";

export default function Home() {
  return (
    <div className="min-h-screen">
      <section className="relative overflow-hidden">
        <div className="absolute inset-0">
          <img
            src="https://images.unsplash.com/photo-1515879218367-8466d910aaa4?q=80&w=1600&auto=format&fit=crop"
            alt="CI/CD background"
            className="w-full h-full object-cover opacity-20"
          />
        </div>
        <div className="relative mx-auto max-w-6xl px-6 py-16">
          <div className="flex flex-col gap-6">
            <div className="flex items-center gap-2">
              <Badge className="w-fit" variant="secondary">轻量级 • 自托管</Badge>
              <StatusBadge />
            </div>
            <h1 className="text-3xl sm:text-5xl font-bold tracking-tight">
              轻量级 CI/CD 与远程运维控制台
            </h1>
            <p className="text-muted-foreground max-w-3xl">
              统一管理项目、构建包、目标机、发布步骤、回滚、远程进程和日志操作。
              当前实现采用 Next.js、libSQL、SSH/SFTP 与环境变量鉴权，并明确区分本地验证和生产验收。
            </p>
            <div className="flex flex-wrap gap-3">
              <Link href="/dashboard"><Button>项目总览</Button></Link>
              <Link href="/projects"><Button variant="secondary">项目与仓库</Button></Link>
              <Link href="/deployments"><Button variant="secondary">部署与监控</Button></Link>
              <Link href="/deployments/history"><Button variant="secondary">发布历史</Button></Link>
              <Link href="/control"><Button variant="secondary">应用控制台</Button></Link>
              <Link href="/users"><Button variant="ghost">用户与权限</Button></Link>
            </div>
          </div>
        </div>
      </section>

      <Separator />

      <section className="mx-auto max-w-6xl px-6 py-12 grid gap-6 sm:grid-cols-2 lg:grid-cols-4">
        <Card>
          <CardHeader>
            <CardTitle>技术栈</CardTitle>
          </CardHeader>
          <CardContent className="space-y-2 text-sm text-muted-foreground">
            <p>应用：Next.js 15 + React 19</p>
            <p>数据：本机 SQLite / libSQL</p>
            <p>远程：SSH2 + SFTP</p>
            <p>校验：TypeScript + ESLint</p>
          </CardContent>
        </Card>
        <Card>
          <CardHeader>
            <CardTitle>核心能力</CardTitle>
          </CardHeader>
          <CardContent className="space-y-2 text-sm text-muted-foreground">
            <p>项目与构建包管理</p>
            <p>目标机和凭据边界</p>
            <p>发布步骤与历史记录</p>
            <p>进程、日志与回滚操作</p>
          </CardContent>
        </Card>
        <Card>
          <CardHeader>
            <CardTitle>权限管理</CardTitle>
          </CardHeader>
          <CardContent className="space-y-2 text-sm text-muted-foreground">
            <p>管理员凭据由服务端配置</p>
            <p>API 使用独立 Bearer Token</p>
            <p>敏感配置不进入代码仓库</p>
            <p>目标凭据加密后存储</p>
          </CardContent>
        </Card>
        <Card>
          <CardHeader>
            <CardTitle>验证状态</CardTitle>
          </CardHeader>
          <CardContent className="space-y-2 text-sm text-muted-foreground">
            <p>依赖审计、Lint 与生产构建通过</p>
            <p>受保护 API 已完成拒绝路径测试</p>
            <p>本地合成数据库支持可重复演示</p>
            <p>真实 SSH 与生产部署仍需验收</p>
          </CardContent>
        </Card>
      </section>
    </div>
  );
}

import Link from "next/link";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Separator } from "@/components/ui/separator";

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
            <Badge className="w-fit" variant="secondary">轻量级 • 自托管</Badge>
            <h1 className="text-3xl sm:text-5xl font-bold tracking-tight">
              轻量级 CI/CD 平台（Rails + SQLite）
            </h1>
            <p className="text-muted-foreground max-w-3xl">
              目标：拉取 Git/SVN 项目，编译打包，部署到线上服务器；读取服务器目录与进程，
              并通过 Web 界面启动/停止/重启应用；支持用户权限管理；可通过 nohup 管理 Java 项目。
            </p>
            <div className="flex flex-wrap gap-3">
              <Link href="/dashboard"><Button>项目总览</Button></Link>
              <Link href="/projects"><Button variant="secondary">项目与仓库</Button></Link>
              <Link href="/deployments"><Button variant="secondary">部署与监控</Button></Link>
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
            <p>后端：Ruby on Rails</p>
            <p>数据库：SQLite3</p>
            <p>界面：中文 UI</p>
            <p>进程：nohup 管理 Java</p>
          </CardContent>
        </Card>
        <Card>
          <CardHeader>
            <CardTitle>核心能力</CardTitle>
          </CardHeader>
          <CardContent className="space-y-2 text-sm text-muted-foreground">
            <p>• 拉取 Git / SVN 项目</p>
            <p>• 编译与打包流水线</p>
            <p>• 部署到远程服务器</p>
            <p>• 目录、进程读取与控制</p>
          </CardContent>
        </Card>
        <Card>
          <CardHeader>
            <CardTitle>权限管理</CardTitle>
          </CardHeader>
          <CardContent className="space-y-2 text-sm text-muted-foreground">
            <p>角色：管理员 / 开发者 / 访客</p>
            <p>资源：项目、流水线、部署、控制</p>
            <p>粒度：读、写、执行</p>
          </CardContent>
        </Card>
        <Card>
          <CardHeader>
            <CardTitle>下一步</CardTitle>
          </CardHeader>
          <CardContent className="space-y-2 text-sm text-muted-foreground">
            <p>在 Rails 中落库模型与控制器。</p>
            <p>接入 SSH 与进程管理（nohup）。</p>
            <p>完善权限中间件与审计日志。</p>
          </CardContent>
        </Card>
      </section>
    </div>
  );
}
"use client";

import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";

export default function DashboardPage() {
  return (
    <div className="mx-auto max-w-6xl px-6 py-10 space-y-8">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-semibold">项目总览</h1>
        <Badge variant="secondary">演示界面</Badge>
      </div>

      <div className="grid gap-6 sm:grid-cols-2 lg:grid-cols-4">
        <Card>
          <CardHeader>
            <CardTitle>项目数量</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-3xl font-bold">6</p>
            <p className="text-xs text-muted-foreground mt-2">Git 4 / SVN 2</p>
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
            <p className="text-3xl font-bold">4 台</p>
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
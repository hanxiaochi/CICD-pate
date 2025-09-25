"use client";

import { useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Label } from "@/components/ui/label";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import Link from "next/link";
import { toast } from "sonner";
import { apiUrl } from "@/lib/api";

export default function LoginPage() {
  const router = useRouter();
  const qp = useSearchParams();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!email || !password) {
      toast.error("请输入用户名/邮箱与密码");
      return;
    }
    setLoading(true);
    try {
      const res = await fetch(apiUrl("/api/login"), {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ email, password }),
      });
      if (!res.ok) {
        const j = await res.json().catch(() => ({}));
        throw new Error(j?.error || "登录失败");
      }
      const data = await res.json();
      localStorage.setItem("bearer_token", data.token);
      toast.success("登录成功");
      const redirect = qp.get("redirect") || "/dashboard";
      router.push(redirect);
    } catch (err: any) {
      toast.error(err?.message || "登录失败");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="mx-auto max-w-md px-6 py-10">
      <Card>
        <CardHeader>
          <CardTitle>登录</CardTitle>
        </CardHeader>
        <CardContent>
          <form className="space-y-5" onSubmit={handleSubmit}>
            <div className="space-y-2">
              <Label htmlFor="email">用户名/邮箱</Label>
              <Input id="email" type="text" value={email} onChange={(e) => setEmail(e.target.value)} placeholder="admin" />
            </div>
            <div className="space-y-2">
              <Label htmlFor="password">密码</Label>
              <Input id="password" type="password" autoComplete="off" value={password} onChange={(e) => setPassword(e.target.value)} />
            </div>
            <Button className="w-full" type="submit" disabled={loading}>
              {loading ? "登录中..." : "登录"}
            </Button>
            <p className="text-xs text-muted-foreground text-center">默认管理员：用户名 admin，密码 admin123。</p>
            <p className="text-center text-sm"><Link href="/" className="text-primary hover:underline">返回首页</Link></p>
          </form>
        </CardContent>
      </Card>
    </div>
  );
}
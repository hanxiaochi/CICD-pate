"use client";

import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { Moon, Sun } from "lucide-react";
import { useEffect, useState } from "react";

const links = [
  { href: "/dashboard", label: "总览" },
  { href: "/projects", label: "项目" },
  { href: "/deployments", label: "部署" },
  { href: "/control", label: "控制台" },
  { href: "/users", label: "用户" },
];

export const NavBar = () => {
  const pathname = usePathname();
  const router = useRouter();
  const [theme, setTheme] = useState<"light" | "dark">("light");
  const [token, setToken] = useState<string | null>(null);

  useEffect(() => {
    const stored = (typeof window !== "undefined" && localStorage.getItem("theme")) as
      | "light"
      | "dark"
      | null;
    const prefersDark = window.matchMedia && window.matchMedia("(prefers-color-scheme: dark)").matches;
    const next = stored || (prefersDark ? "dark" : "light");
    setTheme(next);
  }, []);

  useEffect(() => {
    if (typeof document === "undefined") return;
    const root = document.documentElement;
    if (theme === "dark") {
      root.classList.add("dark");
    } else {
      root.classList.remove("dark");
    }
    try {
      localStorage.setItem("theme", theme);
    } catch {}
  }, [theme]);

  // sync token from localStorage
  useEffect(() => {
    try {
      setToken(localStorage.getItem("bearer_token"));
    } catch {}
  }, [pathname]);

  // Keyboard shortcut: press "T" to toggle theme
  useEffect(() => {
    const onKeyDown = (e: KeyboardEvent) => {
      if (e.key.toLowerCase() === "t" && !e.altKey && !e.ctrlKey && !e.metaKey) {
        e.preventDefault();
        setTheme((t) => (t === "dark" ? "light" : "dark"));
      }
    };
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  }, []);

  const handleLogout = () => {
    try {
      localStorage.removeItem("bearer_token");
    } catch {}
    setToken(null);
    router.push("/login");
  };

  return (
    <header className="sticky top-0 z-40 w-full border-b bg-background/80 backdrop-blur supports-[backdrop-filter]:bg-background/60">
      <div className="mx-auto max-w-6xl px-6 h-14 flex items-center justify-between">
        <Link href="/" className="font-semibold">CI/CD 面板</Link>
        <nav className="flex items-center gap-4 text-sm">
          {links.map(({ href, label }) => {
            const active = pathname === href || pathname.startsWith(`${href}/`);
            return (
              <Link
                key={href}
                href={href}
                aria-current={active ? "page" : undefined}
                className={
                  "px-2 py-1 rounded-md transition-colors " +
                  (active
                    ? "bg-secondary text-foreground"
                    : "text-muted-foreground hover:text-foreground")
                }
              >
                {label}
              </Link>
            );
          })}
        </nav>
        <div className="flex items-center gap-2">
          <button
            type="button"
            onClick={() => setTheme((t) => (t === "dark" ? "light" : "dark"))}
            className="inline-flex items-center justify-center w-9 h-9 rounded-md border hover:bg-accent"
            aria-label="切换主题"
            title="切换主题 (T)"
          >
            {theme === "dark" ? (
              <Sun className="h-4 w-4" />
            ) : (
              <Moon className="h-4 w-4" />
            )}
          </button>
          {token ? (
            <button
              type="button"
              onClick={handleLogout}
              className="inline-flex items-center justify-center h-9 rounded-md border px-3 text-sm hover:bg-accent"
              aria-label="退出"
            >
              退出
            </button>
          ) : (
            <Link
              href="/login"
              className="inline-flex items-center justify-center h-9 rounded-md border px-3 text-sm text-muted-foreground hover:text-foreground hover:bg-accent"
            >
              登录
            </Link>
          )}
        </div>
      </div>
    </header>
  );
};
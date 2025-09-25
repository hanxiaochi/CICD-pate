import type { Metadata } from "next";
import "./globals.css";
import VisualEditsMessenger from "../visual-edits/VisualEditsMessenger";
import ErrorReporter from "@/components/ErrorReporter";
import Script from "next/script";
import { NavBar } from "@/components/NavBar";
import { Toaster } from "@/components/ui/sonner";

export const metadata: Metadata = {
  title: "轻量级 CI/CD 面板",
  description: "Rails + SQLite 的轻量级自托管 CI/CD 平台：拉取 Git/SVN、编译打包、部署到线上、读取目录与进程并通过 Web 控制应用。",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="zh-CN">
      <body className="antialiased">
        <ErrorReporter />
        <Script
          src="https://slelguoygbfzlpylpxfs.supabase.co/storage/v1/object/public/scripts//route-messenger.js"
          strategy="afterInteractive"
          data-target-origin="*"
          data-message-type="ROUTE_CHANGE"
          data-include-search-params="true"
          data-only-in-iframe="true"
          data-debug="true"
          data-custom-data='{"appName": "YourApp", "version": "1.0.0", "greeting": "hi"}'
        />
        {/* Global Navbar */}
        <NavBar />
        <Toaster richColors position="top-right" />
        {children}
        <VisualEditsMessenger />
      </body>
    </html>
  );
}
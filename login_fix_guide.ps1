#!/usr/bin/env powershell

# CICD系统登录修复 - 启动指南
# =====================================

Write-Host "🚀 CICD系统登录修复启动指南" -ForegroundColor Green
Write-Host "=================================" -ForegroundColor Green

# 检查Docker Desktop状态
Write-Host "`n📋 步骤1: 检查Docker状态" -ForegroundColor Yellow
try {
    $dockerVersion = docker --version 2>$null
    if ($dockerVersion) {
        Write-Host "✅ Docker已安装: $dockerVersion" -ForegroundColor Green
        
        # 测试Docker是否可用
        try {
            docker ps 2>$null | Out-Null
            Write-Host "✅ Docker Desktop正在运行" -ForegroundColor Green
            $dockerRunning = $true
        } catch {
            Write-Host "❌ Docker Desktop未运行" -ForegroundColor Red
            $dockerRunning = $false
        }
    } else {
        Write-Host "❌ Docker未安装或不在PATH中" -ForegroundColor Red
        $dockerRunning = $false
    }
} catch {
    Write-Host "❌ Docker检查失败" -ForegroundColor Red
    $dockerRunning = $false
}

# 检查Ruby状态
Write-Host "`n📋 步骤2: 检查Ruby状态" -ForegroundColor Yellow
try {
    $rubyVersion = ruby --version 2>$null
    if ($rubyVersion) {
        Write-Host "✅ Ruby已安装: $rubyVersion" -ForegroundColor Green
        $rubyAvailable = $true
    } else {
        Write-Host "❌ Ruby未安装或不在PATH中" -ForegroundColor Red
        $rubyAvailable = $false
    }
} catch {
    Write-Host "❌ Ruby检查失败" -ForegroundColor Red
    $rubyAvailable = $false
}

Write-Host "`n🔧 登录问题修复说明" -ForegroundColor Cyan
Write-Host "===================" -ForegroundColor Cyan
Write-Host "✅ 会话密钥长度已修复（32字符以上）"
Write-Host "✅ 添加了网页登录处理路由 POST /login"
Write-Host "✅ 添加了登录失败错误页面"
Write-Host "✅ 添加了退出登录功能"
Write-Host "✅ 创建了美观的登录界面"
Write-Host "✅ 预设了默认管理员账户"

Write-Host "`n🚦 启动选项" -ForegroundColor Magenta
Write-Host "============" -ForegroundColor Magenta

if ($dockerRunning) {
    Write-Host "`n选项1: Docker方式启动 (推荐)" -ForegroundColor Green
    Write-Host "-----------------------------"
    Write-Host "docker-compose down" -ForegroundColor White
    Write-Host "docker-compose up --build" -ForegroundColor White
    Write-Host ""
    Write-Host "📍 启动后访问：http://localhost:4567"
    Write-Host "🔑 默认账户：admin / admin123"
    
    Write-Host "`n🎯 现在就启动Docker版本吗？(y/n): " -ForegroundColor Yellow -NoNewline
    $choice = Read-Host
    if ($choice -eq 'y' -or $choice -eq 'Y') {
        Write-Host "`n🚀 正在启动Docker版本..." -ForegroundColor Green
        docker-compose down
        docker-compose up --build
    }
} elseif ($rubyAvailable) {
    Write-Host "`n选项2: Ruby直接运行" -ForegroundColor Yellow
    Write-Host "-------------------"
    Write-Host "ruby start_docker.rb" -ForegroundColor White
    Write-Host ""
    Write-Host "📍 启动后访问：http://localhost:4567"
    Write-Host "🔑 默认账户：admin / admin123"
    
    Write-Host "`n🎯 现在就启动Ruby版本吗？(y/n): " -ForegroundColor Yellow -NoNewline
    $choice = Read-Host
    if ($choice -eq 'y' -or $choice -eq 'Y') {
        Write-Host "`n🚀 正在启动Ruby版本..." -ForegroundColor Green
        ruby start_docker.rb
    }
} else {
    Write-Host "`n❌ 启动需求不满足" -ForegroundColor Red
    Write-Host "=================" -ForegroundColor Red
    
    if (-not $dockerRunning) {
        Write-Host "🔧 启动Docker Desktop："
        Write-Host "   1. 打开Docker Desktop应用程序"
        Write-Host "   2. 等待Docker完全启动（托盘图标正常）"
        Write-Host "   3. 重新运行此脚本"
    }
    
    if (-not $rubyAvailable) {
        Write-Host "🔧 安装Ruby："
        Write-Host "   1. 访问 https://rubyinstaller.org/"
        Write-Host "   2. 下载并安装Ruby 3.0+"
        Write-Host "   3. 重新运行此脚本"
    }
}

Write-Host "`n📋 登录测试步骤" -ForegroundColor Cyan
Write-Host "===============" -ForegroundColor Cyan
Write-Host "1. 🌐 访问 http://localhost:4567"
Write-Host "2. 📝 使用默认账户: admin / admin123"
Write-Host "3. 🔐 点击'登录系统'按钮"
Write-Host "4. ✅ 登录成功后查看系统仪表板"
Write-Host "5. 🧪 测试API端点功能"

Write-Host "`n🔍 故障排除" -ForegroundColor Red
Write-Host "============" -ForegroundColor Red
Write-Host "如果登录仍有问题："
Write-Host "• 检查浏览器控制台是否有JavaScript错误"
Write-Host "• 尝试清除浏览器缓存和Cookie"
Write-Host "• 检查服务器日志输出"
Write-Host "• 确认数据库初始化成功日志"

Write-Host "`n📄 其他资源" -ForegroundColor Blue
Write-Host "============" -ForegroundColor Blue
Write-Host "• 登陆测试页面：./login_test.html"
Write-Host "• Docker解决方案文档：./DOCKER_SOLUTION.md"
Write-Host "• 快速重启脚本：./docker_restart.sh"

Write-Host "`n🎉 修复完成！系统现在应该可以正常登录了。" -ForegroundColor Green
Write-Host "如果仍有问题，请查看服务器启动日志获取详细错误信息。" -ForegroundColor Yellow
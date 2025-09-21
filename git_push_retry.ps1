#!/usr/bin/env powershell

# Git推送重试脚本 - 用于网络不稳定环境
# =====================================

Write-Host "🔄 Git推送重试脚本启动" -ForegroundColor Green
Write-Host "======================" -ForegroundColor Green

$maxRetries = 5
$retryDelay = 10  # 秒
$attempt = 1

while ($attempt -le $maxRetries) {
    Write-Host "`n📡 第 $attempt 次尝试推送到远程仓库..." -ForegroundColor Yellow
    
    try {
        # 尝试推送
        $output = git push origin master 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ 推送成功！" -ForegroundColor Green
            Write-Host "推送输出:" -ForegroundColor Cyan
            Write-Host $output
            
            # 验证推送状态
            Write-Host "`n🔍 验证远程仓库状态..." -ForegroundColor Blue
            git remote show origin
            
            Write-Host "`n🎉 代码已成功推送到 GitHub！" -ForegroundColor Green
            Write-Host "仓库地址: https://github.com/hanxiaochi/CICD-pate.git" -ForegroundColor Cyan
            
            exit 0
        } else {
            throw "Git推送失败: $output"
        }
    }
    catch {
        Write-Host "❌ 第 $attempt 次推送失败: $($_.Exception.Message)" -ForegroundColor Red
        
        if ($attempt -lt $maxRetries) {
            Write-Host "⏰ 等待 $retryDelay 秒后重试..." -ForegroundColor Yellow
            Start-Sleep -Seconds $retryDelay
            
            # 检查网络连通性
            Write-Host "🌐 检查GitHub连通性..." -ForegroundColor Blue
            try {
                $response = Invoke-WebRequest -Uri "https://github.com" -TimeoutSec 10 -UseBasicParsing
                if ($response.StatusCode -eq 200) {
                    Write-Host "✅ GitHub连接正常" -ForegroundColor Green
                } else {
                    Write-Host "⚠️  GitHub连接异常，状态码: $($response.StatusCode)" -ForegroundColor Yellow
                }
            } catch {
                Write-Host "❌ GitHub连接失败: $($_.Exception.Message)" -ForegroundColor Red
            }
            
            $retryDelay += 5  # 逐步增加重试间隔
        }
        
        $attempt++
    }
}

Write-Host "`n💔 所有推送尝试都失败了" -ForegroundColor Red
Write-Host "===========================" -ForegroundColor Red
Write-Host "可能的解决方案:" -ForegroundColor Yellow
Write-Host "1. 检查网络连接是否稳定"
Write-Host "2. 检查GitHub Personal Access Token是否有效"
Write-Host "3. 尝试使用VPN或更换网络环境"
Write-Host "4. 稍后手动执行: git push origin master"
Write-Host ""
Write-Host "📋 当前提交状态:" -ForegroundColor Cyan
git log --oneline -3

Write-Host "`n🔧 手动推送命令:" -ForegroundColor Blue
Write-Host "git push origin master"

exit 1
#!/bin/bash
# CICD系统启动脚本

cd "$(dirname "$0")"

# 设置模式
export CICD_MODE=${CICD_MODE:-simple}
export RACK_ENV=production

echo "🚀 启动CICD系统 (模式: $CICD_MODE)..."
echo "访问地址: http://localhost:4567"
echo "默认账户: admin / admin123"
echo "================================="

ruby app.rb
#!/bin/bash
# CICD系统启动脚本

cd "$(dirname "$0")"

# 设置模式
export CICD_MODE=${CICD_MODE:-simple}
export RACK_ENV=production

echo "启动CICD系统 (模式: $CICD_MODE)..."
ruby app.rb

#!/bin/bash
# Docker 快速重启脚本 - 彻底解决数据库问题

echo "=== CICD Docker 快速重启 ==="

# 停止并删除旧容器
echo "1. 清理旧容器..."
docker-compose down --volumes --remove-orphans
docker system prune -f

# 重新构建并启动
echo "2. 重新构建系统..."
docker-compose build --no-cache

echo "3. 启动新容器..."
docker-compose up -d

# 等待启动
echo "4. 等待服务启动..."
sleep 10

# 验证服务
echo "5. 验证服务状态..."
curl -s http://localhost:4567/api/health | jq . || echo "等待服务完全启动..."

echo "6. 显示日志..."
docker-compose logs --tail=20

echo "=== 重启完成 ==="
echo "访问地址: http://localhost:4567"
echo "查看日志: docker-compose logs -f"
echo "验证系统: ruby docker_verify.rb"
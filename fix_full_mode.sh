#!/bin/bash

# CICD系统 - 完整版模式快速修复脚本
# 解决数据库初始化和依赖问题
# ===================================

echo "🔧 CICD完整版模式快速修复"
echo "========================"

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# 步骤1: 停止现有容器
log_step "停止现有Docker容器..."
docker-compose down

# 步骤2: 清理旧数据库
log_step "清理旧数据库文件..."
if [ -f "./cicd.db" ]; then
    rm -f ./cicd.db
    log_info "已删除本地数据库文件"
fi

# 步骤3: 设置完整版模式
log_step "设置完整版模式..."
export CICD_MODE=full
echo "CICD_MODE=full" > .env
log_info "已设置环境变量 CICD_MODE=full"

# 步骤4: 重新构建并启动
log_step "重新构建并启动容器..."
docker-compose up --build -d

# 步骤5: 等待启动完成
log_step "等待服务启动..."
sleep 15

# 步骤6: 检查服务状态
log_step "检查服务状态..."
if docker ps --filter "name=cicd" --format "table {{.Names}}\t{{.Status}}" | grep -q "Up"; then
    log_info "✅ 容器启动成功"
else
    log_error "❌ 容器启动失败"
    echo ""
    echo "查看详细日志:"
    docker-compose logs web
    exit 1
fi

# 步骤7: 测试API连通性
log_step "测试API连通性..."
sleep 5
if curl -s http://localhost:4567/api/health >/dev/null; then
    log_info "✅ API服务正常"
else
    log_warn "⚠️  API可能还在启动中..."
fi

# 步骤8: 显示访问信息
echo ""
log_info "🎉 完整版CICD系统修复完成！"
echo "================================="
echo -e "${BLUE}访问地址:${NC} http://localhost:4567"
echo -e "${BLUE}默认账户:${NC} admin"
echo -e "${BLUE}默认密码:${NC} admin123"
echo ""
echo -e "${GREEN}完整版功能:${NC}"
echo "📂 工作空间管理 - /workspaces"
echo "📁 项目管理 - /projects"
echo "💻 资产管理 - /assets"
echo "👥 用户管理 - /users"
echo "📊 系统监控 - /monitor"
echo ""
echo -e "${YELLOW}管理命令:${NC}"
echo "查看日志: docker-compose logs -f"
echo "重启服务: docker-compose restart"
echo "停止服务: docker-compose down"

# 步骤9: 如果仍有问题，显示诊断命令
echo ""
echo -e "${BLUE}如果还有问题，运行诊断脚本:${NC}"
echo "docker exec -it \$(docker-compose ps -q web) ruby diagnose_full_startup.rb"
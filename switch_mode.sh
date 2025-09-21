#!/bin/bash

# CICD系统 - 模式切换脚本
# 在简化版和完整版之间切换
# ============================

echo "🔄 CICD系统模式切换"
echo "=================="

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# 显示当前状态
echo -e "${BLUE}📋 当前系统状态：${NC}"
if docker ps --filter "name=cicd" --format "table {{.Names}}\t{{.Status}}" | grep -q "Up"; then
    echo "✅ CICD容器正在运行"
    echo "容器状态:"
    docker ps --filter "name=cicd" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
else
    echo "❌ CICD容器未运行"
fi

echo ""
echo -e "${YELLOW}🎯 请选择运行模式：${NC}"
echo "1. 🚀 完整版 - 包含工作空间、项目管理、资产管理等全功能"
echo "2. ⚡ 简化版 - 仅包含基本功能，启动速度快"
echo "3. 📊 查看当前模式"
echo "4. 🔄 重启当前模式"
echo "0. ❌ 退出"

echo ""
read -p "请输入选择 (0-4): " choice

case $choice in
    1)
        echo -e "\n${GREEN}🚀 切换到完整版模式...${NC}"
        echo "停止现有容器..."
        docker-compose down
        
        echo "设置完整版模式..."
        export CICD_MODE=full
        
        echo "启动完整版CICD系统..."
        docker-compose up --build -d
        
        echo ""
        echo -e "${GREEN}✅ 完整版CICD系统启动完成！${NC}"
        echo -e "${BLUE}访问地址：${NC} http://localhost:4567"
        echo -e "${BLUE}默认账户：${NC} admin / admin123"
        echo ""
        echo -e "${YELLOW}完整版功能：${NC}"
        echo "📂 工作空间管理 - /workspaces"
        echo "📁 项目管理 - /projects"
        echo "💻 资产管理 - /assets"
        echo "👥 用户管理 - /users"
        echo "📊 系统监控 - /monitor"
        ;;
        
    2)
        echo -e "\n${GREEN}⚡ 切换到简化版模式...${NC}"
        echo "停止现有容器..."
        docker-compose down
        
        echo "设置简化版模式..."
        export CICD_MODE=simple
        
        echo "启动简化版CICD系统..."
        docker-compose up --build -d
        
        echo ""
        echo -e "${GREEN}✅ 简化版CICD系统启动完成！${NC}"
        echo -e "${BLUE}访问地址：${NC} http://localhost:4567"
        echo -e "${BLUE}默认账户：${NC} admin / admin123"
        echo ""
        echo -e "${YELLOW}简化版功能：${NC}"
        echo "🔐 用户登录认证"
        echo "📊 系统状态监控"
        echo "🔌 基础API接口"
        ;;
        
    3)
        echo -e "\n${BLUE}📊 检查当前模式...${NC}"
        if docker ps --filter "name=cicd" --format "{{.Names}}" | grep -q "cicd"; then
            # 检查容器内的进程来判断当前模式
            container_id=$(docker ps --filter "name=cicd" --format "{{.ID}}" | head -1)
            if [ -n "$container_id" ]; then
                echo "检查运行中的进程..."
                if docker exec "$container_id" ps aux | grep -q "start_full_docker.rb"; then
                    echo -e "${GREEN}当前模式：完整版 🚀${NC}"
                elif docker exec "$container_id" ps aux | grep -q "start_docker.rb"; then
                    echo -e "${YELLOW}当前模式：简化版 ⚡${NC}"
                else
                    echo -e "${RED}无法确定当前模式${NC}"
                fi
            fi
        else
            echo -e "${RED}CICD容器未运行${NC}"
        fi
        ;;
        
    4)
        echo -e "\n${BLUE}🔄 重启当前模式...${NC}"
        docker-compose restart
        echo -e "${GREEN}✅ 重启完成${NC}"
        ;;
        
    0)
        echo -e "\n${BLUE}退出模式切换${NC}"
        exit 0
        ;;
        
    *)
        echo -e "\n${RED}❌ 无效选择${NC}"
        exit 1
        ;;
esac

echo ""
echo -e "${BLUE}🔍 验证部署结果：${NC}"
sleep 3
if curl -s http://localhost:4567/api/health >/dev/null; then
    echo -e "${GREEN}✅ 系统运行正常${NC}"
    echo "可以访问: http://localhost:4567"
else
    echo -e "${RED}❌ 系统可能还在启动中，请稍等...${NC}"
    echo "查看日志: docker-compose logs -f"
fi
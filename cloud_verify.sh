#!/bin/bash

# CICD系统 - 云服务器快速验证脚本
# 用于验证系统部署状态和功能

echo "🔍 CICD系统状态检查"
echo "===================="

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 检查函数
check_docker() {
    echo -e "\n${BLUE}📦 Docker状态检查${NC}"
    echo "----------------"
    
    if command -v docker &> /dev/null; then
        echo -e "${GREEN}✅ Docker已安装:${NC} $(docker --version)"
        
        if sudo docker ps &> /dev/null; then
            echo -e "${GREEN}✅ Docker服务运行正常${NC}"
        else
            echo -e "${RED}❌ Docker服务未运行${NC}"
            return 1
        fi
    else
        echo -e "${RED}❌ Docker未安装${NC}"
        return 1
    fi
}

check_containers() {
    echo -e "\n${BLUE}🐳 容器状态检查${NC}"
    echo "----------------"
    
    if sudo docker-compose ps 2>/dev/null | grep -q "Up"; then
        echo -e "${GREEN}✅ CICD容器运行中${NC}"
        sudo docker-compose ps
    else
        echo -e "${RED}❌ CICD容器未运行${NC}"
        echo "容器状态:"
        sudo docker-compose ps 2>/dev/null || echo "无docker-compose.yml文件"
        return 1
    fi
}

check_ports() {
    echo -e "\n${BLUE}🌐 端口监听检查${NC}"
    echo "----------------"
    
    if ss -tlnp | grep -q ":4567"; then
        echo -e "${GREEN}✅ 端口4567正在监听${NC}"
        ss -tlnp | grep ":4567"
    else
        echo -e "${RED}❌ 端口4567未监听${NC}"
        return 1
    fi
}

check_api() {
    echo -e "\n${BLUE}🔌 API接口检查${NC}"
    echo "---------------"
    
    # 健康检查
    if curl -s http://localhost:4567/api/health > /dev/null; then
        echo -e "${GREEN}✅ 健康检查API正常${NC}"
        echo "响应数据:"
        curl -s http://localhost:4567/api/health | jq . 2>/dev/null || curl -s http://localhost:4567/api/health
    else
        echo -e "${RED}❌ 健康检查API失败${NC}"
    fi
    
    echo ""
    
    # 版本信息
    if curl -s http://localhost:4567/api/version > /dev/null; then
        echo -e "${GREEN}✅ 版本信息API正常${NC}"
        echo "版本数据:"
        curl -s http://localhost:4567/api/version | jq . 2>/dev/null || curl -s http://localhost:4567/api/version
    else
        echo -e "${RED}❌ 版本信息API失败${NC}"
    fi
}

check_login() {
    echo -e "\n${BLUE}🔐 登录功能检查${NC}"
    echo "----------------"
    
    # 测试登录API
    LOGIN_RESPONSE=$(curl -s -X POST http://localhost:4567/api/login \
        -H "Content-Type: application/json" \
        -d '{"username":"admin","password":"admin123"}' 2>/dev/null)
    
    if echo "$LOGIN_RESPONSE" | grep -q "success.*true"; then
        echo -e "${GREEN}✅ 登录API正常${NC}"
        echo "登录响应:"
        echo "$LOGIN_RESPONSE" | jq . 2>/dev/null || echo "$LOGIN_RESPONSE"
    else
        echo -e "${RED}❌ 登录API失败${NC}"
        echo "错误响应: $LOGIN_RESPONSE"
    fi
}

check_database() {
    echo -e "\n${BLUE}🗄️  数据库状态检查${NC}"
    echo "------------------"
    
    # 通过健康检查API获取数据库状态
    DB_STATUS=$(curl -s http://localhost:4567/api/health 2>/dev/null | grep -o '"database":"[^"]*"' | cut -d'"' -f4)
    
    if [ "$DB_STATUS" = "healthy" ]; then
        echo -e "${GREEN}✅ 数据库状态正常${NC}"
    else
        echo -e "${RED}❌ 数据库状态异常: $DB_STATUS${NC}"
    fi
    
    # 检查数据库文件（如果可以访问容器内部）
    if sudo docker exec -it $(sudo docker-compose ps -q web 2>/dev/null) ls /app/cicd.db &>/dev/null; then
        echo -e "${GREEN}✅ 数据库文件存在${NC}"
    else
        echo -e "${YELLOW}⚠️  无法检查数据库文件${NC}"
    fi
}

check_logs() {
    echo -e "\n${BLUE}📋 系统日志检查${NC}"
    echo "----------------"
    
    echo "最新20行应用日志:"
    sudo docker-compose logs --tail=20 web 2>/dev/null || echo "无法获取日志"
}

check_resources() {
    echo -e "\n${BLUE}💻 系统资源检查${NC}"
    echo "------------------"
    
    echo "内存使用情况:"
    free -h
    
    echo -e "\n磁盘使用情况:"
    df -h
    
    echo -e "\n容器资源使用:"
    sudo docker stats --no-stream 2>/dev/null || echo "无法获取容器统计信息"
}

get_access_info() {
    echo -e "\n${BLUE}🌍 访问信息${NC}"
    echo "============"
    
    # 获取服务器IP
    SERVER_IP=$(curl -s http://ifconfig.me 2>/dev/null || curl -s http://ipinfo.io/ip 2>/dev/null || echo "无法获取外网IP")
    LOCAL_IP=$(ip route get 1 | awk '{print $7}' | head -1 2>/dev/null || echo "无法获取内网IP")
    
    echo "外网访问地址: http://$SERVER_IP:4567"
    echo "内网访问地址: http://$LOCAL_IP:4567"
    echo "本地访问地址: http://localhost:4567"
    echo ""
    echo "默认登录账户:"
    echo "用户名: admin"
    echo "密码: admin123"
}

show_management_commands() {
    echo -e "\n${BLUE}🛠️  管理命令${NC}"
    echo "============"
    echo "查看实时日志: sudo docker-compose logs -f"
    echo "重启服务: sudo docker-compose restart"
    echo "停止服务: sudo docker-compose down"
    echo "启动服务: sudo docker-compose up -d"
    echo "重新构建: sudo docker-compose up --build -d"
    echo "查看容器状态: sudo docker-compose ps"
    echo "进入容器: sudo docker exec -it \$(sudo docker-compose ps -q web) /bin/bash"
}

# 主检查流程
main() {
    local failed_checks=0
    
    check_docker || ((failed_checks++))
    check_containers || ((failed_checks++))
    check_ports || ((failed_checks++))
    check_api || ((failed_checks++))
    check_login || ((failed_checks++))
    check_database || ((failed_checks++))
    check_logs
    check_resources
    get_access_info
    show_management_commands
    
    echo -e "\n${BLUE}📊 检查总结${NC}"
    echo "============"
    
    if [ $failed_checks -eq 0 ]; then
        echo -e "${GREEN}🎉 所有检查通过！系统运行正常。${NC}"
        echo -e "${GREEN}您可以访问上述地址开始使用CICD系统。${NC}"
    else
        echo -e "${RED}❌ 发现 $failed_checks 个问题，请检查上述输出。${NC}"
        echo -e "${YELLOW}建议查看详细日志: sudo docker-compose logs web${NC}"
    fi
}

# 运行检查
main "$@"
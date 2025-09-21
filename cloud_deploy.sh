#!/bin/bash

# CICD系统 - 云服务器一键部署脚本
# ===================================

echo "🚀 CICD系统云服务器一键部署脚本"
echo "================================="

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
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

# 检查是否为root用户
check_root() {
    if [[ $EUID -eq 0 ]]; then
        log_warn "检测到root用户，建议使用普通用户+sudo方式运行"
    fi
}

# 检测系统类型
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
    else
        log_error "无法检测操作系统类型"
        exit 1
    fi
    
    log_info "检测到系统: $OS $VER"
}

# 安装基础依赖
install_dependencies() {
    log_step "安装基础依赖..."
    
    if [[ "$OS" == *"CentOS"* ]] || [[ "$OS" == *"OpenCloudOS"* ]] || [[ "$OS" == *"Red Hat"* ]]; then
        sudo yum update -y
        sudo yum install -y git curl wget net-tools firewalld
    elif [[ "$OS" == *"Ubuntu"* ]] || [[ "$OS" == *"Debian"* ]]; then
        sudo apt update && sudo apt upgrade -y
        sudo apt install -y git curl wget net-tools ufw
    else
        log_warn "未识别的系统类型，请手动安装: git curl wget net-tools"
    fi
    
    log_info "✅ 基础依赖安装完成"
}

# 安装Docker
install_docker() {
    log_step "安装Docker..."
    
    # 检查Docker是否已安装
    if command -v docker &> /dev/null; then
        log_info "Docker已安装，版本: $(docker --version)"
        return 0
    fi
    
    # 下载并安装Docker
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    rm get-docker.sh
    
    # 启动Docker服务
    sudo systemctl start docker
    sudo systemctl enable docker
    
    # 将当前用户添加到docker组（可选）
    if [[ $EUID -ne 0 ]]; then
        sudo usermod -aG docker $USER
        log_warn "已将用户 $USER 添加到docker组，请重新登录以生效"
    fi
    
    log_info "✅ Docker安装完成"
}

# 安装Docker Compose
install_docker_compose() {
    log_step "安装Docker Compose..."
    
    # 检查Docker Compose是否已安装
    if command -v docker-compose &> /dev/null; then
        log_info "Docker Compose已安装，版本: $(docker-compose --version)"
        return 0
    fi
    
    # 安装Docker Compose
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    
    # 验证安装
    if command -v docker-compose &> /dev/null; then
        log_info "✅ Docker Compose安装完成，版本: $(docker-compose --version)"
    else
        log_error "Docker Compose安装失败"
        exit 1
    fi
}

# 配置防火墙
configure_firewall() {
    log_step "配置防火墙..."
    
    if [[ "$OS" == *"CentOS"* ]] || [[ "$OS" == *"OpenCloudOS"* ]] || [[ "$OS" == *"Red Hat"* ]]; then
        sudo systemctl start firewalld
        sudo systemctl enable firewalld
        sudo firewall-cmd --permanent --add-port=4567/tcp
        sudo firewall-cmd --reload
        log_info "✅ firewalld防火墙配置完成"
    elif [[ "$OS" == *"Ubuntu"* ]] || [[ "$OS" == *"Debian"* ]]; then
        sudo ufw --force enable
        sudo ufw allow 4567/tcp
        log_info "✅ ufw防火墙配置完成"
    fi
    
    log_warn "⚠️  请确保在云服务器控制台的安全组中也开放了4567端口"
}

# 克隆代码
clone_project() {
    log_step "克隆项目代码..."
    
    DEPLOY_DIR="$HOME/CICD-pate"
    
    if [ -d "$DEPLOY_DIR" ]; then
        log_info "项目目录已存在，更新代码..."
        cd "$DEPLOY_DIR"
        git pull origin master
    else
        log_info "克隆新项目..."
        git clone https://github.com/hanxiaochi/CICD-pate.git "$DEPLOY_DIR"
        cd "$DEPLOY_DIR"
    fi
    
    log_info "✅ 项目代码准备完成"
}

# 启动服务
start_service() {
    log_step "启动CICD服务..."
    
    cd "$DEPLOY_DIR"
    
    # 停止现有容器
    sudo docker-compose down 2>/dev/null || true
    
    # 构建并启动服务
    sudo docker-compose up --build -d
    
    # 等待服务启动
    log_info "等待服务启动..."
    sleep 10
    
    # 检查服务状态
    if sudo docker-compose ps | grep -q "Up"; then
        log_info "✅ 服务启动成功"
    else
        log_error "服务启动失败，查看日志:"
        sudo docker-compose logs
        exit 1
    fi
}

# 验证部署
verify_deployment() {
    log_step "验证部署..."
    
    # 检查端口监听
    if ss -tlnp | grep -q ":4567"; then
        log_info "✅ 端口4567正在监听"
    else
        log_error "端口4567未监听"
        return 1
    fi
    
    # 测试API
    sleep 5
    if curl -s http://localhost:4567/api/health > /dev/null; then
        log_info "✅ API健康检查通过"
    else
        log_warn "API健康检查失败，可能还在启动中"
    fi
    
    # 获取服务器IP
    SERVER_IP=$(curl -s http://ifconfig.me 2>/dev/null || curl -s http://ipinfo.io/ip 2>/dev/null || echo "您的服务器IP")
    
    echo ""
    echo "🎉 部署完成！"
    echo "================================="
    echo "访问地址: http://$SERVER_IP:4567"
    echo "默认账户: admin"
    echo "默认密码: admin123"
    echo ""
    echo "管理命令:"
    echo "查看日志: sudo docker-compose logs -f"
    echo "重启服务: sudo docker-compose restart"
    echo "停止服务: sudo docker-compose down"
    echo "更新代码: git pull && sudo docker-compose up --build -d"
    echo ""
}

# 主函数
main() {
    log_info "开始部署CICD系统到云服务器..."
    
    check_root
    detect_os
    install_dependencies
    install_docker
    install_docker_compose
    configure_firewall
    clone_project
    start_service
    verify_deployment
    
    log_info "🚀 所有部署步骤完成！"
}

# 错误处理
set -e
trap 'log_error "部署过程中出现错误，请查看上述日志"; exit 1' ERR

# 运行主函数
main "$@"
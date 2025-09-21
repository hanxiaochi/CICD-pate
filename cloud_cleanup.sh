#!/bin/bash

# CICD系统 - 一键清理脚本
# 清理所有相关目录、Docker镜像和容器
# =====================================

echo "🧹 CICD系统一键清理脚本"
echo "======================"

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

# 确认清理操作
confirm_cleanup() {
    echo -e "${YELLOW}⚠️  警告：此操作将完全清理CICD系统相关的所有内容！${NC}"
    echo "将要执行的清理操作："
    echo "  🗂️  删除项目目录: ~/CICD-pate, ~/cicd-system"
    echo "  🐳 停止并删除所有CICD相关容器"
    echo "  🖼️  删除所有CICD相关Docker镜像"
    echo "  📦 清理Docker系统缓存"
    echo "  🧽 清理未使用的Docker资源"
    echo ""
    echo -e "${RED}❗ 此操作不可逆！请确保重要数据已备份。${NC}"
    echo ""
    read -p "确定要继续清理吗？(输入 'yes' 确认): " confirm
    
    if [ "$confirm" != "yes" ]; then
        log_info "清理操作已取消"
        exit 0
    fi
}

# 停止并删除相关容器
cleanup_containers() {
    log_step "清理Docker容器..."
    
    # 停止所有CICD相关容器
    log_info "停止CICD相关容器..."
    docker stop $(docker ps -aq --filter "name=cicd") 2>/dev/null || true
    docker stop $(docker ps -aq --filter "name=pate") 2>/dev/null || true
    
    # 删除所有CICD相关容器
    log_info "删除CICD相关容器..."
    docker rm -f $(docker ps -aq --filter "name=cicd") 2>/dev/null || true
    docker rm -f $(docker ps -aq --filter "name=pate") 2>/dev/null || true
    
    # 通过compose文件清理（如果存在）
    if [ -d "$HOME/CICD-pate" ]; then
        cd "$HOME/CICD-pate"
        if [ -f "docker-compose.yml" ]; then
            log_info "通过docker-compose清理容器..."
            docker-compose down --remove-orphans 2>/dev/null || true
        fi
    fi
    
    if [ -d "$HOME/cicd-system" ]; then
        cd "$HOME/cicd-system"
        if [ -f "docker-compose.yml" ]; then
            log_info "通过docker-compose清理容器..."
            docker-compose down --remove-orphans 2>/dev/null || true
        fi
    fi
    
    log_info "✅ 容器清理完成"
}

# 删除相关镜像
cleanup_images() {
    log_step "清理Docker镜像..."
    
    # 删除CICD相关镜像
    log_info "删除CICD相关镜像..."  
    docker rmi -f $(docker images --filter "reference=*cicd*" -q) 2>/dev/null || true
    docker rmi -f $(docker images --filter "reference=*pate*" -q) 2>/dev/null || true
    docker rmi -f $(docker images --filter "reference=cicd-pate*" -q) 2>/dev/null || true
    
    # 删除无标签镜像
    log_info "删除无标签镜像..."
    docker rmi -f $(docker images --filter "dangling=true" -q) 2>/dev/null || true
    
    log_info "✅ 镜像清理完成"
}

# 清理Docker系统缓存
cleanup_docker_system() {
    log_step "清理Docker系统缓存..."
    
    # 清理构建缓存
    log_info "清理构建缓存..."
    docker builder prune -f 2>/dev/null || true
    
    # 清理未使用的网络
    log_info "清理未使用的网络..."
    docker network prune -f 2>/dev/null || true
    
    # 清理未使用的卷
    log_info "清理未使用的数据卷..."
    docker volume prune -f 2>/dev/null || true
    
    # 系统级清理
    log_info "执行系统级清理..."
    docker system prune -f 2>/dev/null || true
    
    log_info "✅ Docker系统清理完成"
}

# 删除项目目录
cleanup_directories() {
    log_step "清理项目目录..."
    
    # 可能的项目目录列表
    POSSIBLE_DIRS=(
        "$HOME/CICD-pate"
        "$HOME/cicd-system" 
        "$HOME/cicd-pate"
        "/opt/CICD-pate"
        "/opt/cicd-system"
        "/tmp/CICD-pate"
        "./CICD-pate"
        "./cicd-system"
    )
    
    for dir in "${POSSIBLE_DIRS[@]}"; do
        if [ -d "$dir" ]; then
            log_info "删除目录: $dir"
            rm -rf "$dir"
            if [ $? -eq 0 ]; then
                log_info "✅ 已删除: $dir"
            else
                log_error "❌ 删除失败: $dir"
            fi
        fi
    done
    
    log_info "✅ 目录清理完成"
}

# 清理相关文件
cleanup_related_files() {
    log_step "清理相关配置文件..."
    
    # 清理可能的配置文件
    POSSIBLE_FILES=(
        "$HOME/.cicd_config"
        "$HOME/.cicd_pate"
        "/etc/cicd-pate"
        "/var/log/cicd-pate.log"
        "/tmp/cicd-*.log"
    )
    
    for file in "${POSSIBLE_FILES[@]}"; do
        if [ -f "$file" ] || [ -d "$file" ]; then
            log_info "删除文件/目录: $file"
            rm -rf "$file" 2>/dev/null || true
        fi
    done
    
    # 清理临时文件
    find /tmp -name "*cicd*" -type f -delete 2>/dev/null || true
    find /tmp -name "*pate*" -type f -delete 2>/dev/null || true
    
    log_info "✅ 相关文件清理完成"
}

# 清理防火墙规则（可选）
cleanup_firewall() {
    log_step "清理防火墙规则..."
    
    # CentOS/OpenCloudOS/RHEL
    if command -v firewall-cmd &> /dev/null; then
        log_info "清理firewalld规则..."
        firewall-cmd --permanent --remove-port=4567/tcp 2>/dev/null || true
        firewall-cmd --reload 2>/dev/null || true
    fi
    
    # Ubuntu/Debian
    if command -v ufw &> /dev/null; then
        log_info "清理ufw规则..."
        ufw delete allow 4567/tcp 2>/dev/null || true
    fi
    
    log_info "✅ 防火墙规则清理完成"
}

# 显示清理前状态
show_before_status() {
    log_step "清理前状态检查..."
    
    echo "Docker容器状态:"
    docker ps -a --filter "name=cicd" --filter "name=pate" 2>/dev/null || echo "无相关容器"
    
    echo -e "\nDocker镜像状态:"
    docker images --filter "reference=*cicd*" --filter "reference=*pate*" 2>/dev/null || echo "无相关镜像"
    
    echo -e "\n项目目录状态:"
    for dir in "$HOME/CICD-pate" "$HOME/cicd-system"; do
        if [ -d "$dir" ]; then
            echo "存在: $dir ($(du -sh $dir 2>/dev/null | cut -f1))"
        fi
    done
}

# 显示清理后状态
show_after_status() {
    log_step "清理后状态验证..."
    
    echo "剩余Docker容器:"
    docker ps -a 2>/dev/null | head -5
    
    echo -e "\n剩余Docker镜像:"
    docker images 2>/dev/null | head -5
    
    echo -e "\nDocker系统空间使用:"
    docker system df 2>/dev/null || echo "无法获取Docker磁盘使用信息"
    
    echo -e "\n目录清理验证:"
    for dir in "$HOME/CICD-pate" "$HOME/cicd-system"; do
        if [ -d "$dir" ]; then
            echo "❌ 仍存在: $dir"
        else
            echo "✅ 已清理: $dir"
        fi
    done
}

# 生成重新部署命令
show_redeploy_commands() {
    echo -e "\n${BLUE}🚀 重新部署命令${NC}"
    echo "================"
    echo "一键部署："
    echo "curl -fsSL https://raw.githubusercontent.com/hanxiaochi/CICD-pate/master/cloud_deploy.sh | bash"
    echo ""
    echo "或手动部署："
    echo "git clone https://github.com/hanxiaochi/CICD-pate.git"
    echo "cd CICD-pate"
    echo "chmod +x cloud_deploy.sh"
    echo "./cloud_deploy.sh"
}

# 主清理流程
main() {
    log_info "开始CICD系统清理流程..."
    
    # 显示清理前状态
    show_before_status
    
    # 确认清理
    confirm_cleanup
    
    # 执行清理步骤
    cleanup_containers
    cleanup_images
    cleanup_docker_system
    cleanup_directories
    cleanup_related_files
    cleanup_firewall
    
    # 显示清理后状态
    show_after_status
    
    # 显示重新部署命令
    show_redeploy_commands
    
    echo -e "\n${GREEN}🎉 CICD系统清理完成！${NC}"
    echo -e "${GREEN}现在可以重新部署全新的CICD系统了。${NC}"
}

# 快速模式（跳过确认）
if [ "$1" = "--force" ] || [ "$1" = "-f" ]; then
    log_warn "强制清理模式，跳过确认"
    # 跳过确认，直接执行清理步骤
    cleanup_containers
    cleanup_images  
    cleanup_docker_system
    cleanup_directories
    cleanup_related_files
    show_after_status
    show_redeploy_commands
    echo -e "\n${GREEN}🎉 强制清理完成！${NC}"
    exit 0
fi

# 帮助信息
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo "CICD系统一键清理脚本"
    echo ""
    echo "用法："
    echo "  $0          # 交互式清理（需要确认）"
    echo "  $0 --force  # 强制清理（跳过确认）"
    echo "  $0 --help   # 显示帮助信息"
    echo ""
    echo "清理内容："
    echo "  - 停止并删除所有CICD相关Docker容器"
    echo "  - 删除所有CICD相关Docker镜像"
    echo "  - 清理Docker系统缓存和未使用资源"
    echo "  - 删除项目目录（~/CICD-pate, ~/cicd-system等）"
    echo "  - 清理相关配置文件"
    echo "  - 清理防火墙规则"
    exit 0
fi

# 错误处理
set -e
trap 'log_error "清理过程中出现错误，请检查上述输出"; exit 1' ERR

# 执行主流程
main "$@"

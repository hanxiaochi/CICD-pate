#!/bin/bash

# CICD系统 - 云服务器完整测试工作流
# 一键清理 + 重新部署 + 验证测试
# ===================================

echo "🔄 CICD系统云服务器完整测试工作流"
echo "================================="

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 配置参数
REPO_URL="https://xget.xi-xu.me/gh/hanxiaochi/CICD-pate.git"
DEPLOY_DIR="$HOME/CICD-pate"
CLEANUP_SCRIPT="cloud_cleanup.sh"
DEPLOY_SCRIPT="cloud_deploy.sh"
VERIFY_SCRIPT="cloud_verify.sh"

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

log_highlight() {
    echo -e "${CYAN}[HIGHLIGHT]${NC} $1"
}

# 显示工作流菜单
show_menu() {
    echo -e "\n${CYAN}🎯 请选择测试工作流：${NC}"
    echo "1. 🧹 仅清理环境"
    echo "2. 🚀 仅重新部署"
    echo "3. 🔍 仅验证测试"
    echo "4. 🔄 完整流程：清理 → 部署 → 验证"
    echo "5. 🆘 快速修复：强制清理 → 重新部署"
    echo "6. 📊 环境状态检查"
    echo "0. ❌ 退出"
    echo ""
    read -p "请输入选择 (0-6): " choice
}

# 环境状态检查
check_environment() {
    log_step "检查环境状态..."
    
    echo -e "\n${BLUE}🐳 Docker状态：${NC}"
    if command -v docker &> /dev/null; then
        echo "✅ Docker已安装: $(docker --version)"
        if docker ps &> /dev/null; then
            echo "✅ Docker服务运行正常"
            echo "运行中的容器数量: $(docker ps -q | wc -l)"  
            echo "CICD相关容器: $(docker ps --filter 'name=cicd' --filter 'name=pate' --format 'table {{.Names}}\t{{.Status}}' 2>/dev/null || echo '无')"
        else
            echo "❌ Docker服务未运行"
        fi
        
        echo -e "\n镜像统计:"
        echo "总镜像数量: $(docker images -q | wc -l 2>/dev/null || echo 0)"
        echo "CICD相关镜像: $(docker images --filter 'reference=*cicd*' --filter 'reference=*pate*' --format 'table {{.Repository}}\t{{.Tag}}\t{{.Size}}' 2>/dev/null || echo '无')"
    else
        echo "❌ Docker未安装"
    fi
    
    echo -e "\n${BLUE}📁 项目目录状态：${NC}"
    DIRS=("$HOME/CICD-pate" "$HOME/cicd-system" "/opt/CICD-pate")
    for dir in "${DIRS[@]}"; do
        if [ -d "$dir" ]; then
            echo "✅ 存在: $dir ($(du -sh $dir 2>/dev/null | cut -f1))"
        else
            echo "❌ 不存在: $dir"
        fi
    done
    
    echo -e "\n${BLUE}🌐 网络连通性：${NC}"
    if curl -s --connect-timeout 5 https://github.com &> /dev/null; then
        echo "✅ GitHub连接正常"
    else
        echo "❌ GitHub连接失败"
    fi
    
    if ss -tlnp | grep -q ":4567"; then
        echo "✅ 端口4567正在监听"
    else
        echo "❌ 端口4567未监听"
    fi
    
    echo -e "\n${BLUE}💾 系统资源：${NC}"
    echo "内存使用: $(free -h | grep '^Mem:' | awk '{print $3 "/" $2}')"
    echo "磁盘使用: $(df -h / | tail -1 | awk '{print $3 "/" $2 " (" $5 ")"}')"
}

# 执行清理
run_cleanup() {
    log_step "执行环境清理..."
    
    if [ -f "$CLEANUP_SCRIPT" ]; then
        chmod +x "$CLEANUP_SCRIPT"
        if [ "$1" = "--force" ]; then
            ./"$CLEANUP_SCRIPT" --force
        else
            ./"$CLEANUP_SCRIPT"
        fi
    else
        log_warn "清理脚本不存在，手动执行清理..."
        
        # 手动清理步骤
        docker stop $(docker ps -aq --filter "name=cicd" --filter "name=pate") 2>/dev/null || true
        docker rm -f $(docker ps -aq --filter "name=cicd" --filter "name=pate") 2>/dev/null || true
        docker rmi -f $(docker images --filter "reference=*cicd*" --filter "reference=*pate*" -q) 2>/dev/null || true
        docker system prune -f 2>/dev/null || true
        
        rm -rf "$HOME/CICD-pate" "$HOME/cicd-system" 2>/dev/null || true
        
        log_info "手动清理完成"
    fi
}

# 执行部署
run_deploy() {
    log_step "执行重新部署..."
    
    # 确保在正确目录
    cd "$HOME"
    
    # 克隆最新代码
    if [ -d "$DEPLOY_DIR" ]; then
        log_info "更新现有代码..."
        cd "$DEPLOY_DIR"
        git pull origin master || {
            log_warn "更新失败，删除目录重新克隆..."
            cd "$HOME"
            rm -rf "$DEPLOY_DIR"
            git clone "$REPO_URL" "$DEPLOY_DIR"
        }
    else
        log_info "克隆最新代码..."
        git clone "$REPO_URL" "$DEPLOY_DIR"
    fi
    
    cd "$DEPLOY_DIR"
    
    # 执行部署脚本
    if [ -f "$DEPLOY_SCRIPT" ]; then
        chmod +x "$DEPLOY_SCRIPT"
        ./"$DEPLOY_SCRIPT"
    else
        log_error "部署脚本不存在: $DEPLOY_SCRIPT"
        return 1
    fi
}

# 执行验证
run_verification() {
    log_step "执行系统验证..."
    
    if [ -d "$DEPLOY_DIR" ]; then
        cd "$DEPLOY_DIR"
    fi
    
    if [ -f "$VERIFY_SCRIPT" ]; then
        chmod +x "$VERIFY_SCRIPT"
        ./"$VERIFY_SCRIPT"
    else
        log_warn "验证脚本不存在，执行简单验证..."
        
        # 简单验证步骤
        echo "检查容器状态:"
        docker ps --filter "name=cicd" --filter "name=pate"
        
        echo -e "\n检查端口监听:"
        ss -tlnp | grep ":4567" || echo "端口4567未监听"
        
        echo -e "\n测试API健康检查:"
        if curl -s http://localhost:4567/api/health; then
            echo -e "\n✅ API健康检查通过"
        else
            echo -e "\n❌ API健康检查失败"
        fi
    fi
}

# 显示完成信息
show_completion_info() {
    local server_ip=$(curl -s http://ifconfig.me 2>/dev/null || curl -s http://ipinfo.io/ip 2>/dev/null || echo "服务器IP")
    
    echo -e "\n${GREEN}🎉 工作流完成！${NC}"
    echo "================================="
    echo -e "${CYAN}访问信息：${NC}"
    echo "外网地址: http://$server_ip:4567"
    echo "内网地址: http://localhost:4567"
    echo ""
    echo -e "${CYAN}默认登录：${NC}"
    echo "用户名: admin"
    echo "密码: admin123"
    echo ""
    echo -e "${CYAN}管理命令：${NC}"
    echo "查看日志: sudo docker-compose logs -f"
    echo "重启服务: sudo docker-compose restart"
    echo "停止服务: sudo docker-compose down"
    echo ""
    echo -e "${CYAN}测试命令：${NC}"
    echo "curl http://localhost:4567/api/health"
    echo "curl http://localhost:4567/api/version"
}

# 主流程控制
main() {
    log_info "CICD系统云服务器测试工作流启动"
    
    # 如果有命令行参数，直接执行对应功能
    case "$1" in
        "cleanup"|"clean"|"c")
            run_cleanup
            exit 0
            ;;
        "deploy"|"d")
            run_deploy
            show_completion_info
            exit 0
            ;;
        "verify"|"test"|"v")
            run_verification
            exit 0
            ;;
        "full"|"f")
            run_cleanup --force
            run_deploy
            run_verification
            show_completion_info
            exit 0
            ;;
        "fix")
            run_cleanup --force
            run_deploy
            show_completion_info
            exit 0
            ;;
        "status"|"s")
            check_environment
            exit 0
            ;;
        "--help"|"-h")
            echo "CICD系统云服务器测试工作流"
            echo ""
            echo "用法:"
            echo "  $0                # 交互式菜单"
            echo "  $0 cleanup        # 仅清理环境"
            echo "  $0 deploy         # 仅重新部署"  
            echo "  $0 verify         # 仅验证测试"
            echo "  $0 full           # 完整流程"
            echo "  $0 fix            # 快速修复"
            echo "  $0 status         # 状态检查"
            exit 0
            ;;
    esac
    
    # 交互式菜单
    while true; do
        show_menu
        
        case $choice in
            1)
                run_cleanup
                ;;
            2)
                run_deploy
                show_completion_info
                ;;
            3)
                run_verification
                ;;
            4)
                log_highlight "执行完整流程：清理 → 部署 → 验证"
                run_cleanup
                echo -e "\n⏳ 等待5秒后开始部署..."
                sleep 5
                run_deploy
                echo -e "\n⏳ 等待10秒后开始验证..."
                sleep 10
                run_verification
                show_completion_info
                ;;
            5)
                log_highlight "执行快速修复：强制清理 → 重新部署"
                run_cleanup --force
                echo -e "\n⏳ 等待5秒后开始部署..."
                sleep 5
                run_deploy
                show_completion_info
                ;;
            6)
                check_environment
                ;;
            0)
                log_info "退出工作流"
                exit 0
                ;;
            *)
                log_error "无效选择，请重新输入"
                continue
                ;;
        esac
        
        echo -e "\n按回车键继续..."
        read
    done
}

# 错误处理
set -e
trap 'log_error "工作流执行过程中出现错误"; exit 1' ERR

# 执行主程序
main "$@"
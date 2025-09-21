#!/bin/bash

# CICD系统启动诊断工具

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

log_debug() {
    echo -e "${BLUE}[DEBUG]${NC} $1"
}

echo "========================================"
echo "CICD系统启动诊断工具"
echo "========================================"

# 1. 检查基本环境
check_basic_environment() {
    log_info "检查基本环境..."
    
    # 检查Ruby
    if command -v ruby &>/dev/null; then
        ruby_version=$(ruby --version)
        log_info "Ruby版本: $ruby_version"
    else
        log_error "Ruby未安装"
        return 1
    fi
    
    # 检查Bundler
    if command -v bundler &>/dev/null; then
        bundler_version=$(bundle --version)
        log_info "Bundler版本: $bundler_version"
    else
        log_error "Bundler未安装"
        return 1
    fi
    
    # 检查Gem源
    log_info "当前Gem源:"
    gem sources -l
    
    return 0
}

# 2. 检查文件结构
check_file_structure() {
    log_info "检查文件结构..."
    
    local required_files=(
        "app_refactored.rb"
        "config.ru"
        "puma.rb"
        "Gemfile"
        "config/application.rb"
    )
    
    local missing_files=()
    
    for file in "${required_files[@]}"; do
        if [ -f "$file" ]; then
            log_info "✓ $file"
        else
            log_error "✗ $file (缺失)"
            missing_files+=("$file")
        fi
    done
    
    if [ ${#missing_files[@]} -gt 0 ]; then
        log_error "缺失关键文件: ${missing_files[*]}"
        return 1
    fi
    
    return 0
}

# 3. 检查依赖
check_dependencies() {
    log_info "检查依赖安装..."
    
    if [ ! -f "Gemfile.lock" ]; then
        log_warn "Gemfile.lock不存在，需要运行bundle install"
        return 1
    fi
    
    # 检查bundle状态
    if bundle check &>/dev/null; then
        log_info "✓ 所有依赖已正确安装"
    else
        log_warn "依赖有问题，需要重新安装"
        return 1
    fi
    
    return 0
}

# 4. 检查目录权限
check_directories() {
    log_info "检查目录和权限..."
    
    local required_dirs=("tmp" "logs")
    
    for dir in "${required_dirs[@]}"; do
        if [ -d "$dir" ]; then
            if [ -w "$dir" ]; then
                log_info "✓ $dir (可写)"
            else
                log_warn "✗ $dir (无写权限)"
            fi
        else
            log_warn "✗ $dir (不存在)"
            mkdir -p "$dir" 2>/dev/null && log_info "✓ $dir (已创建)" || log_error "✗ 无法创建 $dir"
        fi
    done
}

# 5. 检查端口
check_ports() {
    log_info "检查端口占用..."
    
    local app_port=${PORT:-4567}
    
    if netstat -tuln 2>/dev/null | grep -q ":$app_port "; then
        log_warn "端口 $app_port 已被占用"
        log_debug "占用端口的进程:"
        netstat -tulnp 2>/dev/null | grep ":$app_port " || true
        return 1
    else
        log_info "✓ 端口 $app_port 可用"
    fi
    
    return 0
}

# 6. 测试配置
test_configurations() {
    log_info "测试配置文件..."
    
    # 测试Ruby语法
    if ruby -c app_refactored.rb &>/dev/null; then
        log_info "✓ app_refactored.rb 语法正确"
    else
        log_error "✗ app_refactored.rb 语法错误"
        ruby -c app_refactored.rb
        return 1
    fi
    
    # 测试config.ru
    if ruby -c config.ru &>/dev/null; then
        log_info "✓ config.ru 语法正确"
    else
        log_error "✗ config.ru 语法错误"
        ruby -c config.ru
        return 1
    fi
    
    # 测试Puma配置
    if bundle exec puma -C puma.rb --dry-run &>/dev/null; then
        log_info "✓ puma.rb 配置正确"
    else
        log_warn "✗ puma.rb 配置可能有问题"
        log_debug "Puma配置测试输出:"
        bundle exec puma -C puma.rb --dry-run 2>&1 || true
    fi
    
    return 0
}

# 7. 尝试启动测试
test_startup() {
    log_info "测试应用启动..."
    
    # 设置环境变量
    export RACK_ENV=development
    export PORT=4567
    
    # 尝试加载应用
    log_debug "尝试加载应用..."
    if timeout 10 ruby -e "require_relative 'app_refactored'; puts 'Application loaded successfully'" 2>/dev/null; then
        log_info "✓ 应用加载成功"
    else
        log_error "✗ 应用加载失败"
        log_debug "详细错误信息:"
        ruby -e "require_relative 'app_refactored'; puts 'Application loaded successfully'" 2>&1 || true
        return 1
    fi
    
    return 0
}

# 主诊断流程
main_diagnosis() {
    local checks=(
        "check_basic_environment"
        "check_file_structure"
        "check_dependencies"
        "check_directories"
        "check_ports"
        "test_configurations"
        "test_startup"
    )
    
    local failed_checks=()
    
    for check in "${checks[@]}"; do
        echo ""
        if ! $check; then
            failed_checks+=("$check")
        fi
    done
    
    echo ""
    echo "========================================"
    echo "诊断结果"
    echo "========================================"
    
    if [ ${#failed_checks[@]} -eq 0 ]; then
        log_info "✅ 所有检查通过！系统应该可以正常启动"
        echo ""
        echo "建议启动命令:"
        echo "  开发模式: ./start_refactored.sh start development"
        echo "  生产模式: ./start_refactored.sh start production"
    else
        log_error "❌ 发现 ${#failed_checks[@]} 个问题"
        echo ""
        echo "失败的检查:"
        for check in "${failed_checks[@]}"; do
            echo "  - $check"
        done
        echo ""
        echo "建议修复步骤:"
        echo "1. 运行: ./start_refactored.sh install"
        echo "2. 运行: ./fix_gem_build.sh"
        echo "3. 重新运行此诊断: ./diagnose_startup.sh"
    fi
}

# 简化诊断（仅基本检查）
simple_diagnosis() {
    log_info "运行简化诊断..."
    check_basic_environment
    check_file_structure
    check_dependencies
}

# 显示帮助
show_help() {
    echo "CICD系统启动诊断工具"
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  help, -h, --help    显示帮助信息"
    echo "  simple              运行简化诊断"
    echo "  full                运行完整诊断 (默认)"
    echo ""
    echo "示例:"
    echo "  $0                  # 完整诊断"
    echo "  $0 simple           # 简化诊断"
    echo ""
}

# 命令行参数处理
case "${1:-full}" in
    help|-h|--help)
        show_help
        ;;
    simple)
        simple_diagnosis
        ;;
    full|*)
        main_diagnosis
        ;;
esac
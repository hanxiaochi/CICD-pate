#!/bin/bash

# Ruby Gem编译错误修复脚本
# 专门用于解决native extension编译失败问题

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

echo "========================================"
echo "Ruby Gem Native Extension 修复工具"
echo "========================================"

# 检测系统类型
detect_system() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$ID $VERSION_ID"
    else
        uname -s
    fi
}

# 检查当前环境
check_environment() {
    log_info "检查当前环境..."
    
    echo "系统信息: $(detect_system)"
    echo "Ruby版本: $(ruby --version 2>/dev/null || echo '未安装')"
    echo "GCC版本: $(gcc --version 2>/dev/null | head -1 || echo '未安装')"
    echo "Make版本: $(make --version 2>/dev/null | head -1 || echo '未安装')"
    
    # 检查Ruby头文件
    if find /usr/include /usr/local/include /opt -name "ruby.h" 2>/dev/null | head -1 | grep -q "ruby.h"; then
        ruby_h_path=$(find /usr/include /usr/local/include /opt -name "ruby.h" 2>/dev/null | head -1)
        echo "Ruby头文件: $ruby_h_path"
    else
        echo "Ruby头文件: ❌ 未找到"
    fi
    
    echo ""
}

# 安装开发依赖
install_dev_dependencies() {
    log_info "安装Ruby开发依赖..."
    
    if command -v yum &>/dev/null; then
        log_info "使用yum安装开发包..."
        
        # 安装基本开发工具
        sudo yum groupinstall -y "Development Tools" 2>/dev/null || {
            sudo yum install -y gcc gcc-c++ make patch
        }
        
        # 安装Ruby开发包
        sudo yum install -y ruby-devel 2>/dev/null || {
            log_warn "ruby-devel包不可用，安装基本编译依赖..."
            sudo yum install -y openssl-devel libffi-devel readline-devel zlib-devel
        }
        
        # 安装其他可能需要的开发包
        sudo yum install -y libyaml-devel sqlite-devel bzip2-devel ncurses-devel
        
    elif command -v apt-get &>/dev/null; then
        log_info "使用apt-get安装开发包..."
        sudo apt-get update
        sudo apt-get install -y ruby-dev build-essential
        sudo apt-get install -y libssl-dev libffi-dev libreadline-dev zlib1g-dev
        
    elif command -v dnf &>/dev/null; then
        log_info "使用dnf安装开发包..."
        sudo dnf install -y ruby-devel gcc gcc-c++ make
        sudo dnf install -y openssl-devel libffi-devel readline-devel zlib-devel
        
    else
        log_error "未识别的包管理器，请手动安装开发包"
        return 1
    fi
}

# 修复gem环境
fix_gem_environment() {
    log_info "修复gem环境..."
    
    # 清理gem缓存
    gem cleanup 2>/dev/null || true
    
    # 更新RubyGems
    log_info "更新RubyGems..."
    gem update --system --no-document 2>/dev/null || true
    
    # 重新安装bundler
    log_info "重新安装bundler..."
    gem uninstall bundler -a -x 2>/dev/null || true
    gem install bundler --no-document
    
    # 配置gem安装选项
    log_info "配置gem编译选项..."
    bundle config set --global build.bigdecimal --with-cflags="-O2 -g -pipe"
    bundle config set --global jobs 1  # 单线程编译，避免内存不足
    
    # 设置环境变量
    export MAKE="make -j1"
    export MAKEFLAGS="-j1"
}

# 尝试手动编译有问题的gem
fix_problematic_gems() {
    log_info "尝试修复有问题的gem..."
    
    # 常见的需要编译的gem
    problematic_gems=("bigdecimal" "psych" "strscan" "date")
    
    for gem_name in "${problematic_gems[@]}"; do
        if gem list | grep -q "$gem_name"; then
            log_info "重新编译 $gem_name..."
            gem uninstall "$gem_name" -a -x 2>/dev/null || true
            gem install "$gem_name" --no-document 2>/dev/null || {
                log_warn "$gem_name 安装失败，可能需要手动处理"
            }
        fi
    done
}

# 主修复流程
main() {
    check_environment
    
    log_info "开始修复流程..."
    
    # 1. 安装开发依赖
    if ! install_dev_dependencies; then
        log_error "开发依赖安装失败"
        exit 1
    fi
    
    # 2. 修复gem环境
    fix_gem_environment
    
    # 3. 修复有问题的gem
    fix_problematic_gems
    
    # 4. 重新尝试bundle install
    log_info "重新运行bundle install..."
    
    if [ -f Gemfile ]; then
        bundle clean --force 2>/dev/null || true
        
        if bundle install --retry=3 --jobs=1; then
            log_info "✅ bundle install 成功！"
        else
            log_error "❌ bundle install 仍然失败"
            log_error "建议检查以下内容："
            echo "1. 系统是否有足够的内存和磁盘空间"
            echo "2. 网络连接是否正常"
            echo "3. 是否需要特定的系统库"
            echo ""
            echo "详细错误信息请查看上面的输出"
            exit 1
        fi
    else
        log_error "当前目录没有Gemfile"
        exit 1
    fi
    
    log_info "✅ 所有修复完成！"
}

# 显示帮助
show_help() {
    echo "Ruby Gem Native Extension 修复工具"
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  help, -h, --help    显示帮助信息"
    echo "  check               仅检查环境，不进行修复"
    echo "  deps                仅安装开发依赖"
    echo "  gems                仅修复gem环境"
    echo ""
    echo "示例:"
    echo "  $0                  # 完整修复流程"
    echo "  $0 check           # 检查环境"
    echo "  $0 deps            # 安装开发依赖"
    echo ""
}

# 命令行参数处理
case "${1:-main}" in
    help|-h|--help)
        show_help
        ;;
    check)
        check_environment
        ;;
    deps)
        check_environment
        install_dev_dependencies
        ;;
    gems)
        check_environment
        fix_gem_environment
        fix_problematic_gems
        ;;
    main|*)
        main
        ;;
esac
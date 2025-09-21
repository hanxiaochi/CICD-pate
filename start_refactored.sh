#!/bin/bash

# CICD系统启动脚本

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# 检查Ruby环境
check_ruby() {
    log_info "检查Ruby环境..."
    
    if ! command -v ruby &> /dev/null; then
        log_warn "Ruby未安装，开始自动安装Ruby 3.0+..."
        install_ruby
    else
        ruby_version=$(ruby -v | cut -d' ' -f2)
        log_info "Ruby版本: $ruby_version"
        
        # 检查Ruby版本是否满足要求
        if ! ruby -e "exit(RUBY_VERSION.split('.').map(&:to_i) <=> [3, 0, 0]) >= 0"; then
            log_warn "Ruby版本过低，需要3.0+，开始升级..."
            install_ruby
        fi
    fi
    
    # 配置国内镜像源
    configure_ruby_mirrors
    
    if ! command -v bundler &> /dev/null; then
        log_warn "Bundler未安装，正在安装..."
        gem install bundler
    fi
}

# 安装Ruby
install_ruby() {
    log_info "开始安装Ruby 3.0+..."
    
    # 检测操作系统
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        install_ruby_linux
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        install_ruby_macos
    elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
        install_ruby_windows
    else
        log_error "不支持的操作系统: $OSTYPE"
        log_error "请手动安装Ruby 3.0+: https://www.ruby-lang.org/zh_cn/downloads/"
        exit 1
    fi
}

# Linux系统安装Ruby
install_ruby_linux() {
    log_info "在Linux系统上安装Ruby..."
    
    # 检测Linux发行版
    if command -v apt-get &> /dev/null; then
        # Ubuntu/Debian
        log_info "检测到Ubuntu/Debian系统"
        install_ruby_debian
        
    elif command -v yum &> /dev/null; then
        # CentOS/RHEL/OpenCloudOS(腾讯云)
        if grep -q "OpenCloudOS" /etc/os-release 2>/dev/null; then
            log_info "检测到腾讯云OpenCloudOS系统"
            install_ruby_opencloudos
        else
            log_info "检测到CentOS/RHEL系统"
            install_ruby_centos
        fi
        
    elif command -v dnf &> /dev/null; then
        # Fedora
        log_info "检测到Fedora系统"
        install_ruby_fedora
        
    elif command -v zypper &> /dev/null; then
        # openSUSE
        log_info "检测到openSUSE系统"
        install_ruby_opensuse
        
    else
        log_warn "未检测到支持的包管理器，尝试使用RVM安装..."
        install_ruby_with_rvm
    fi
}

# Ubuntu/Debian安装
install_ruby_debian() {
    sudo apt-get update
    sudo apt-get install -y software-properties-common
    sudo apt-add-repository -y ppa:brightbox/ruby-ng
    sudo apt-get update
    sudo apt-get install -y ruby3.2 ruby3.2-dev build-essential
}

# CentOS/RHEL安装
install_ruby_centos() {
    sudo yum install -y centos-release-scl
    sudo yum install -y rh-ruby32 rh-ruby32-ruby-devel gcc gcc-c++ make
    echo 'source /opt/rh/rh-ruby32/enable' >> ~/.bashrc
    source /opt/rh/rh-ruby32/enable
}

# 腾讯云OpenCloudOS安装
install_ruby_opencloudos() {
    log_info "为腾讯云OpenCloudOS系统安装Ruby..."
    
    # 配置OpenCloudOS镜像源
    configure_opencloudos_mirrors
    
    # 安装基本开发工具
    log_info "安装基本开发工具..."
    sudo yum install -y gcc gcc-c++ make patch
    sudo yum install -y openssl-devel libffi-devel readline-devel zlib-devel
    sudo yum install -y libyaml-devel sqlite-devel
    
    # 尝试安装EPEL源（如果失败不中断）
    log_info "尝试配置EPEL源..."
    sudo yum install -y epel-release 2>/dev/null || {
        log_warn "EPEL源安装失败，继续使用官方源"
    }
    
    # 尝试直接安装ruby（通常版本较低）
    if yum list ruby &>/dev/null; then
        log_info "检查yum中的Ruby版本..."
        sudo yum install -y ruby ruby-devel 2>/dev/null || true
        
        # 检查版本是否满足要求
        if command -v ruby &>/dev/null && ruby -e "exit(RUBY_VERSION.split('.').map(&:to_i) <=> [3, 0, 0]) >= 0" 2>/dev/null; then
            log_info "Ruby版本满足要求: $(ruby -v)"
            return 0
        else
            log_warn "yum安装的Ruby版本过低，需要升级"
        fi
    fi
    
    # 使用RVM安装最新版本
    log_info "使用RVM安装Ruby 3.2..."
    install_ruby_with_rvm
}

# 配置OpenCloudOS镜像源
configure_opencloudos_mirrors() {
    log_info "配置OpenCloudOS国内镜像源..."
    
    # 备份原始源文件
    if [ ! -f /etc/yum.repos.d/OpenCloudOS-Base.repo.bak ]; then
        sudo cp /etc/yum.repos.d/OpenCloudOS-Base.repo /etc/yum.repos.d/OpenCloudOS-Base.repo.bak 2>/dev/null || true
    fi
    
    # 配置清华大学镜像源
    cat > /tmp/opencloudos-tuna.repo << 'EOF'
[tuna-opencloudos-base]
name=OpenCloudOS Base - Tsinghua
baseurl=https://mirrors.tuna.tsinghua.edu.cn/opencloudos/$releasever/BaseOS/$basearch/os/
enabled=1
gpgcheck=0
priority=1

[tuna-opencloudos-appstream]
name=OpenCloudOS AppStream - Tsinghua
baseurl=https://mirrors.tuna.tsinghua.edu.cn/opencloudos/$releasever/AppStream/$basearch/os/
enabled=1
gpgcheck=0
priority=1
EOF
    
    # 安装清华镜像源配置
    sudo mv /tmp/opencloudos-tuna.repo /etc/yum.repos.d/ 2>/dev/null || {
        log_warn "镜像源配置失败，使用默认源"
    }
    
    # 清理并更新缓存
    sudo yum clean all &>/dev/null || true
    sudo yum makecache &>/dev/null || true
    
    log_info "镜像源配置完成"
}

# Fedora安装
install_ruby_fedora() {
    sudo dnf install -y ruby ruby-devel gcc gcc-c++ make
}

# openSUSE安装
install_ruby_opensuse() {
    sudo zypper install -y ruby ruby-devel gcc gcc-c++ make
}

# macOS系统安装Ruby
install_ruby_macos() {
    log_info "在macOS系统上安装Ruby..."
    
    if command -v brew &> /dev/null; then
        log_info "使用Homebrew安装Ruby"
        brew install ruby@3.2
        echo 'export PATH="/usr/local/opt/ruby@3.2/bin:$PATH"' >> ~/.zshrc
        echo 'export PATH="/usr/local/opt/ruby@3.2/bin:$PATH"' >> ~/.bash_profile
        source ~/.zshrc 2>/dev/null || source ~/.bash_profile
    else
        log_warn "未检测到Homebrew，请先安装: https://brew.sh/"
        log_info "或使用RVM安装Ruby..."
        install_ruby_with_rvm
    fi
}

# Windows系统安装Ruby
install_ruby_windows() {
    log_info "在Windows系统上安装Ruby..."
    log_warn "请手动下载并安装Ruby 3.0+:"
    log_warn "下载地址: https://rubyinstaller.org/downloads/"
    log_warn "推荐下载: Ruby+Devkit 3.2.x (x64)"
    log_warn "安装完成后重新运行此脚本"
    exit 1
}

# 使用RVM安装Ruby
install_ruby_with_rvm() {
    log_info "使用RVM安装Ruby..."
    
    # 安装必需的依赖
    if command -v yum &> /dev/null; then
        log_info "安装编译依赖..."
        sudo yum groupinstall -y "Development Tools" 2>/dev/null || {
            sudo yum install -y gcc gcc-c++ make patch
        }
        sudo yum install -y openssl-devel libffi-devel readline-devel zlib-devel libyaml-devel sqlite-devel
    elif command -v apt-get &> /dev/null; then
        sudo apt-get update
        sudo apt-get install -y curl gpg build-essential libssl-dev libffi-dev libreadline-dev zlib1g-dev
    fi
    
    # 安装RVM
    if ! command -v rvm &> /dev/null; then
        log_info "下载并安装RVM..."
        
        # 设置代理和镜像源环境变量
        export RVM_RUBY_MIRRORS="https://cache.ruby-china.com/pub/ruby,https://mirrors.tuna.tsinghua.edu.cn/ruby"
        
        # 导入GPG密钥（使用国内代理）
        log_info "导入RVM GPG密钥..."
        curl -sSL https://rvm.io/mpapis.asc | gpg --import - 2>/dev/null || true
        curl -sSL https://rvm.io/pkuczynski.asc | gpg --import - 2>/dev/null || true
        
        # 安装RVM（使用清华镜像）
        log_info "从清华镜像下载RVM安装脚本..."
        curl -sSL https://mirrors.tuna.tsinghua.edu.cn/rvm/install | bash -s stable --ruby 2>/dev/null || {
            log_warn "清华镜像失败，尝试官方源..."
            curl -sSL https://get.rvm.io | bash -s stable
        }
        
        # 加载RVM环境
        if [ -f ~/.rvm/scripts/rvm ]; then
            source ~/.rvm/scripts/rvm
        elif [ -f /usr/local/rvm/scripts/rvm ]; then
            source /usr/local/rvm/scripts/rvm
        fi
        
        # 更新RVM
        rvm get stable 2>/dev/null || true
    fi
    
    # 配置RVM使用国内镜像
    log_info "配置RVM国内镜像源..."
    mkdir -p ~/.rvm/user
    cat > ~/.rvm/user/db << 'EOF'
ruby_url=https://cache.ruby-china.com/pub/ruby
ruby_url=https://mirrors.tuna.tsinghua.edu.cn/ruby
ruby_url=https://ftp.ruby-lang.org/pub/ruby
EOF
    
    # 使用RVM安装Ruby
    log_info "使用RVM安装Ruby 3.2.0..."
    
    # 重新加载RVM
    source ~/.rvm/scripts/rvm 2>/dev/null || source /usr/local/rvm/scripts/rvm 2>/dev/null || true
    
    # 安装Ruby
    rvm install 3.2.0 --disable-binary 2>/dev/null || {
        log_warn "从源码编译安装Ruby..."
        rvm install 3.2.0
    }
    
    rvm use 3.2.0 --default
    
    # 验证安装
    if ruby --version | grep -q "3.2"; then
        log_info "Ruby 3.2.0安装成功: $(ruby --version)"
        return 0
    else
        log_error "Ruby安装失败"
        return 1
    fi
}

# 配置Ruby国内镜像源
configure_ruby_mirrors() {
    log_info "配置Ruby国内镜像源..."
    
    # 配置RubyGems镜像源（优先使用Ruby中国，备用清华大学）
    if gem sources | grep -q "https://rubygems.org/"; then
        log_info "移除官方源并添加国内镜像源..."
        gem sources --remove https://rubygems.org/ 2>/dev/null || true
        
        # 尝试Ruby中国镜像
        if curl -s --connect-timeout 3 --max-time 5 https://gems.ruby-china.com/ > /dev/null 2>&1; then
            log_info "使用Ruby中国镜像源..."
            gem sources --add https://gems.ruby-china.com/ 2>/dev/null || true
            bundle config set --global mirror.https://rubygems.org https://gems.ruby-china.com 2>/dev/null || true
        elif curl -s --connect-timeout 3 --max-time 5 https://mirrors.tuna.tsinghua.edu.cn/rubygems/ > /dev/null 2>&1; then
            log_info "使用清华大学镜像源..."
            gem sources --add https://mirrors.tuna.tsinghua.edu.cn/rubygems/ 2>/dev/null || true
            bundle config set --global mirror.https://rubygems.org https://mirrors.tuna.tsinghua.edu.cn/rubygems 2>/dev/null || true
        elif curl -s --connect-timeout 3 --max-time 5 https://mirrors.aliyun.com/rubygems/ > /dev/null 2>&1; then
            log_info "使用阿里云镜像源..."
            gem sources --add https://mirrors.aliyun.com/rubygems/ 2>/dev/null || true
            bundle config set --global mirror.https://rubygems.org https://mirrors.aliyun.com/rubygems 2>/dev/null || true
        else
            log_warn "所有国内镜像都无法访问，保持默认源"
            gem sources --add https://rubygems.org/ 2>/dev/null || true
        fi
    fi
    
    # 显示当前镜像源
    log_info "当前RubyGems镜像源:"
    gem sources -l 2>/dev/null || log_warn "无法获取gem源列表"
    
    # 设置国内NPM镜像（如果需要）
    if command -v npm &> /dev/null; then
        log_info "配置NPM国内镜像源..."
        npm config set registry https://registry.npmmirror.com 2>/dev/null || true
    fi
    
    # 配置yarn镜像（如果存在）
    if command -v yarn &> /dev/null; then
        log_info "配置Yarn国内镜像源..."
        yarn config set registry https://registry.npmmirror.com 2>/dev/null || true
    fi
}

# 安装依赖
install_dependencies() {
    log_info "安装依赖包..."
    
    if [ -f Gemfile ]; then
        bundle install
    else
        log_error "Gemfile不存在"
        exit 1
    fi
}

# 初始化数据库
init_database() {
    log_info "初始化数据库..."
    
    if [ ! -f cicd.db ]; then
        log_info "创建数据库..."
        # 数据库将在应用启动时自动创建
    else
        log_info "数据库已存在"
    fi
}

# 创建必要目录
create_directories() {
    log_info "创建必要目录..."
    
    directories=("tmp" "logs" "backups" "uploads" "scripts" "ssh_keys")
    
    for dir in "${directories[@]}"; do
        if [ ! -d "$dir" ]; then
            mkdir -p "$dir"
            log_info "创建目录: $dir"
        fi
    done
    
    # 设置适当的权限
    chmod 700 tmp
    chmod 700 ssh_keys
    chmod 755 logs
    chmod 755 backups
}

# 检查端口是否可用
check_ports() {
    log_info "检查端口可用性..."
    
    app_port=${APP_PORT:-4567}
    ws_port=${WEBSOCKET_PORT:-8080}
    
    if netstat -tuln | grep -q ":$app_port "; then
        log_error "端口 $app_port 已被占用"
        exit 1
    fi
    
    if netstat -tuln | grep -q ":$ws_port "; then
        log_warn "WebSocket端口 $ws_port 已被占用"
    fi
    
    log_info "端口检查完成"
}

# 启动应用
start_app() {
    log_info "启动CICD系统..."
    
    if [ "$1" = "development" ]; then
        log_info "开发模式启动"
        bundle exec ruby app_refactored.rb
    elif [ "$1" = "production" ]; then
        log_info "生产模式启动"
        bundle exec puma -C puma.rb app_refactored.rb
    else
        log_info "默认模式启动"
        bundle exec ruby app_refactored.rb
    fi
}

# 停止应用
stop_app() {
    log_info "停止CICD系统..."
    
    if [ -f tmp/puma.pid ]; then
        pid=$(cat tmp/puma.pid)
        if ps -p $pid > /dev/null; then
            kill $pid
            log_info "应用已停止 (PID: $pid)"
        else
            log_warn "PID文件存在但进程不存在"
            rm -f tmp/puma.pid
        fi
    else
        # 尝试查找进程
        pids=$(pgrep -f "app_refactored.rb" || true)
        if [ -n "$pids" ]; then
            kill $pids
            log_info "应用已停止"
        else
            log_warn "没有找到运行中的应用进程"
        fi
    fi
}

# 重启应用
restart_app() {
    log_info "重启CICD系统..."
    stop_app
    sleep 2
    start_app $1
}

# 显示状态
show_status() {
    log_info "检查应用状态..."
    
    if [ -f tmp/puma.pid ]; then
        pid=$(cat tmp/puma.pid)
        if ps -p $pid > /dev/null; then
            log_info "应用正在运行 (PID: $pid)"
            return 0
        else
            log_warn "PID文件存在但进程不存在"
            rm -f tmp/puma.pid
        fi
    fi
    
    pids=$(pgrep -f "app_refactored.rb" || true)
    if [ -n "$pids" ]; then
        log_info "应用正在运行 (PID: $pids)"
        return 0
    else
        log_info "应用未运行"
        return 1
    fi
}

# 显示帮助
show_help() {
    echo "CICD系统启动脚本"
    echo ""
    echo "用法: $0 {start|stop|restart|status|install|help} [mode]"
    echo ""
    echo "命令:"
    echo "  start [mode]    启动应用 (mode: development|production)"
    echo "  stop            停止应用"
    echo "  restart [mode]  重启应用"
    echo "  status          显示应用状态"
    echo "  install         安装依赖和初始化（自动安装Ruby 3.0+）"
    echo "  help            显示帮助信息"
    echo ""
    echo "环境变量:"
    echo "  APP_PORT        应用端口 (默认: 4567)"
    echo "  WEBSOCKET_PORT  WebSocket端口 (默认: 8080)"
    echo "  RACK_ENV        运行环境 (development|production)"
    echo ""
    echo "特性:"
    echo "  • 自动检测并安装Ruby 3.0+"
    echo "  • 自动配置国内RubyGems镜像源"
    echo "  • 支持Linux/macOS/Windows多平台"
    echo "  • 自动创建必需目录和数据库"
    echo ""
    echo "示例:"
    echo "  $0 install              # 安装依赖（包括Ruby）"
    echo "  $0 start development    # 开发模式启动"
    echo "  $0 start production     # 生产模式启动"
    echo "  $0 restart production  # 重启到生产模式"
    echo ""
    echo "项目地址: https://github.com/hanxiaochi/CICD-pate.git"
}

# 安装和初始化
install_system() {
    log_info "开始安装CICD系统..."
    
    check_ruby
    install_dependencies
    create_directories
    init_database
    
    log_info "安装完成！"
    log_info "使用 '$0 start' 启动系统"
}

# 主函数
main() {
    case "$1" in
        start)
            check_ruby
            check_ports
            start_app $2
            ;;
        stop)
            stop_app
            ;;
        restart)
            restart_app $2
            ;;
        status)
            show_status
            ;;
        install)
            install_system
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            echo "未知命令: $1"
            show_help
            exit 1
            ;;
    esac
}

# 执行主函数
main "$@"
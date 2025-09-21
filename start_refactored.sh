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

# 版本比较函数
version_compare() {
    local version1="$1"
    local version2="$2"
    
    # 将版本号拆分为数组
    IFS='.' read -ra VERSION1 <<< "$version1"
    IFS='.' read -ra VERSION2 <<< "$version2"
    
    # 找到最大長度
    local max_length=${#VERSION1[@]}
    if [ ${#VERSION2[@]} -gt $max_length ]; then
        max_length=${#VERSION2[@]}
    fi
    
    # 逐位比較
    for ((i=0; i<max_length; i++)); do
        local v1=${VERSION1[i]:-0}
        local v2=${VERSION2[i]:-0}
        
        if [ $v1 -gt $v2 ]; then
            return 0  # version1 > version2
        elif [ $v1 -lt $v2 ]; then
            return 1  # version1 < version2
        fi
    done
    
    return 0  # 版本相等，返回0（满足要求）
}

# 检查Ruby环境
check_ruby() {
    log_info "检查Ruby环境..."
    
    if ! command -v ruby &> /dev/null; then
        log_warn "Ruby未安装，开始自动安装Ruby 3.0+..."
        install_ruby
    else
        # 获取Ruby版本号（只取数字部分）
        ruby_version=$(ruby -v | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
        log_info "Ruby版本: $ruby_version"
        
        # 检查Ruby版本是否满足要求（>= 3.0.0）
        if version_compare "$ruby_version" "3.0.0"; then
            log_info "Ruby版本满足要求 (>= 3.0): $ruby_version"
        else
            log_warn "Ruby版本过低（$ruby_version），需要3.0+，开始升级..."
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
    
    # 首先尝试安装基本开发工具（不依赖镜像源）
    log_info "安装基本开发工具..."
    if ! install_basic_dev_tools_opencloudos; then
        log_error "基本开发工具安装失败，尝试简化安装模式"
        simple_install_ruby_opencloudos
        return $?
    fi
    
    # 尝试配置镜像源（可选，失败不影响后续流程）
    configure_opencloudos_mirrors
    
    # 尝试安装EPEL源（如果失败不中断）
    log_info "尝试配置EPEL源..."
    sudo yum install -y epel-release 2>/dev/null || {
        log_warn "EPEL源安装失败，直接使用RVM安装Ruby"
    }
    
    # 尝试直接安装ruby（通常版本较低）
    if yum list ruby &>/dev/null; then
        log_info "检查yum中的Ruby版本..."
        sudo yum install -y ruby ruby-devel 2>/dev/null || true
        
        # 检查版本是否满足要求
        if command -v ruby &>/dev/null; then
            current_version=$(ruby -v | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
            if version_compare "$current_version" "3.0.0"; then
                log_info "Ruby版本满足要求: $current_version"
                return 0
            else
                log_warn "yum安装的Ruby版本过低（$current_version），需要升级"
            fi
        fi
    fi
    
    # 使用RVM安装最新版本
    log_info "使用RVM安装Ruby 3.2..."
    if ! install_ruby_with_rvm; then
        log_warn "RVM安装失败，尝试简化安装模式"
        simple_install_ruby_opencloudos
    fi
}

# 安装OpenCloudOS基本开发工具
install_basic_dev_tools_opencloudos() {
    log_info "安装OpenCloudOS基本开发环境..."
    
    # 更新包管理器缓存
    sudo yum clean all &>/dev/null || true
    
    # 安装基本编译工具
    local basic_packages=(
        "gcc"
        "gcc-c++"
        "make"
        "patch"
        "git"
    )
    
    for package in "${basic_packages[@]}"; do
        if ! rpm -q "$package" &>/dev/null; then
            log_info "安装 $package..."
            sudo yum install -y "$package" 2>/dev/null || {
                log_warn "$package 安装失败，尝试继续"
            }
        else
            log_info "$package 已安装"
        fi
    done
    
    # 安装开发库
    local dev_packages=(
        "openssl-devel"
        "libffi-devel"
        "readline-devel"
        "zlib-devel"
        "libyaml-devel"
        "sqlite-devel"
        "bzip2-devel"
        "ncurses-devel"
    )
    
    for package in "${dev_packages[@]}"; do
        if ! rpm -q "$package" &>/dev/null; then
            log_info "安装 $package..."
            sudo yum install -y "$package" 2>/dev/null || {
                log_warn "$package 安装失败，可能影响Ruby编译"
            }
        else
            log_info "$package 已安装"
        fi
    done
    
    # 检查关键工具是否可用
    if ! command -v gcc &>/dev/null; then
        log_error "GCC编译器未安装，无法编译Ruby"
        return 1
    fi
    
    if ! command -v make &>/dev/null; then
        log_error "Make工具未安装，无法编译Ruby"
        return 1
    fi
    
    log_info "基本开发工具安装完成"
    return 0
}

# 配置OpenCloudOS镜像源
configure_opencloudos_mirrors() {
    log_info "配置OpenCloudOS国内镜像源..."
    
    # 备份原始源文件
    if [ ! -f /etc/yum.repos.d/OpenCloudOS-Base.repo.bak ]; then
        sudo cp /etc/yum.repos.d/OpenCloudOS-Base.repo /etc/yum.repos.d/OpenCloudOS-Base.repo.bak 2>/dev/null || true
    fi
    
    # 尝试多个镜像源，按优先级排序
    local mirrors=(
        "aliyun:https://mirrors.aliyun.com/opencloudos"
        "tencent:https://mirrors.cloud.tencent.com/opencloudos"
        "tuna:https://mirrors.tuna.tsinghua.edu.cn/opencloudos"
        "ustc:https://mirrors.ustc.edu.cn/opencloudos"
    )
    
    local selected_mirror=""
    
    # 测试镜像源连通性
    for mirror_info in "${mirrors[@]}"; do
        local name=$(echo $mirror_info | cut -d: -f1)
        local url=$(echo $mirror_info | cut -d: -f2-)
        
        log_info "测试${name}镜像源连接性..."
        if curl -s --connect-timeout 3 --max-time 5 "${url}/" > /dev/null 2>&1; then
            log_info "选择${name}镜像源: ${url}"
            selected_mirror="$url"
            break
        else
            log_warn "${name}镜像源连接失败"
        fi
    done
    
    if [ -n "$selected_mirror" ]; then
        # 配置选中的镜像源
        cat > /tmp/opencloudos-mirror.repo << EOF
[opencloudos-base]
name=OpenCloudOS Base - Mirror
baseurl=$selected_mirror/\$releasever/BaseOS/\$basearch/os/
enabled=1
gpgcheck=0
priority=1

[opencloudos-appstream]
name=OpenCloudOS AppStream - Mirror
baseurl=$selected_mirror/\$releasever/AppStream/\$basearch/os/
enabled=1
gpgcheck=0
priority=1

[opencloudos-extras]
name=OpenCloudOS Extras - Mirror
baseurl=$selected_mirror/\$releasever/extras/\$basearch/os/
enabled=1
gpgcheck=0
priority=1
EOF
        
        # 安装镜像源配置
        sudo mv /tmp/opencloudos-mirror.repo /etc/yum.repos.d/ 2>/dev/null || {
            log_warn "镜像源配置失败，使用默认源"
        }
    else
        log_warn "所有镜像源都无法连接，保持默认配置"
    fi
    
    # 清理并更新缓存
    sudo yum clean all &>/dev/null || true
    sudo yum makecache &>/dev/null || {
        log_warn "更新缓存失败，可能需要检查网络连接"
    }
    
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
ruby_url=https://mirrors.aliyun.com/ruby
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
    
    # 确保Ruby开发环境完整
    ensure_ruby_dev_environment
    
    if [ -f Gemfile ]; then
        # 设置bundler超时和重试
        export BUNDLE_TIMEOUT=300
        export BUNDLE_RETRY=3
        
        log_info "使用bundle安装Ruby gems..."
        bundle install || {
            log_warn "bundle install失败，尝试修复..."
            fix_gem_installation
        }
    else
        log_error "Gemfile不存在"
        exit 1
    fi
}

# 确保Ruby开发环境完整
ensure_ruby_dev_environment() {
    log_info "检查并完善Ruby开发环境..."
    
    # 检查是否有Ruby头文件
    if ! find /usr/include /usr/local/include /opt -name "ruby.h" 2>/dev/null | head -1 | grep -q "ruby.h"; then
        log_warn "检测到缺少Ruby开发头文件，正在安装..."
        install_ruby_dev_packages
    fi
    
    # 检查关键的开发工具
    local missing_tools=()
    
    if ! command -v gcc &>/dev/null; then
        missing_tools+=("gcc")
    fi
    
    if ! command -v make &>/dev/null; then
        missing_tools+=("make")
    fi
    
    if [ ${#missing_tools[@]} -gt 0 ]; then
        log_warn "缺少构建工具: ${missing_tools[*]}，正在安装..."
        install_build_tools "${missing_tools[@]}"
    fi
}

# 安装Ruby开发包
install_ruby_dev_packages() {
    if command -v yum &>/dev/null; then
        # RedHat系列（CentOS/RHEL/OpenCloudOS）
        log_info "为RHEL系列系统安装Ruby开发包..."
        
        # 首先尝试安装ruby-devel
        sudo yum install -y ruby-devel 2>/dev/null || {
            log_warn "ruby-devel安装失败，尝试其他方法..."
            
            # 如果是通过源码编译安装的Ruby，可能需要重新编译
            if [ -d "/usr/local/ruby" ]; then
                log_info "检测到自定义Ruby安装，确保开发环境..."
                ensure_custom_ruby_dev
            else
                # 尝试安装基本开发包
                sudo yum groupinstall -y "Development Tools" 2>/dev/null || true
                sudo yum install -y gcc gcc-c++ make patch
                sudo yum install -y openssl-devel libffi-devel readline-devel zlib-devel
            fi
        }
        
    elif command -v apt-get &>/dev/null; then
        # Debian系列（Ubuntu/Debian）
        log_info "为Debian系列系统安装Ruby开发包..."
        sudo apt-get update
        sudo apt-get install -y ruby-dev build-essential
        
    elif command -v dnf &>/dev/null; then
        # Fedora
        log_info "为Fedora系统安装Ruby开发包..."
        sudo dnf install -y ruby-devel gcc gcc-c++ make
        
    else
        log_warn "未识别的包管理器，请手动安装Ruby开发包"
    fi
}

# 确保自定义Ruby安装的开发环境
ensure_custom_ruby_dev() {
    log_info "配置自定义Ruby安装的开发环境..."
    
    # 检查Ruby配置
    if command -v ruby &>/dev/null; then
        ruby_config=$(ruby -e "puts RbConfig::CONFIG['prefix']" 2>/dev/null || echo "/usr/local/ruby")
        log_info "Ruby安装路径: $ruby_config"
        
        # 确保头文件路径正确
        if [ -d "$ruby_config/include" ]; then
            export C_INCLUDE_PATH="$ruby_config/include:$C_INCLUDE_PATH"
            export CPLUS_INCLUDE_PATH="$ruby_config/include:$CPLUS_INCLUDE_PATH"
            log_info "设置Ruby头文件路径: $ruby_config/include"
        fi
    fi
}

# 修复gem安装问题
fix_gem_installation() {
    log_info "尝试修复gem安装问题..."
    
    # 清理gem缓存
    gem cleanup 2>/dev/null || true
    
    # 更新RubyGems
    log_info "更新RubyGems..."
    gem update --system --no-document 2>/dev/null || true
    
    # 重新安装bundler
    log_info "重新安装bundler..."
    gem uninstall bundler -a -x 2>/dev/null || true
    gem install bundler --no-document
    
    # 清理bundle缓存
    bundle clean --force 2>/dev/null || true
    
    # 重新尝试安装
    log_info "重新尝试bundle install..."
    bundle install --retry=3 --jobs=1 || {
        log_error "gem安装仍然失败，请检查系统环境"
        log_error "可能需要手动安装: sudo yum install ruby-devel gcc make"
        return 1
    }
}

# 安装构建工具
install_build_tools() {
    local tools=("$@")
    
    if command -v yum &>/dev/null; then
        for tool in "${tools[@]}"; do
            log_info "安装 $tool..."
            sudo yum install -y "$tool" 2>/dev/null || {
                log_warn "$tool 安装失败"
            }
        done
    elif command -v apt-get &>/dev/null; then
        sudo apt-get update
        for tool in "${tools[@]}"; do
            log_info "安装 $tool..."
            sudo apt-get install -y "$tool" 2>/dev/null || {
                log_warn "$tool 安装失败"
            }
        done
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
    
    # 确保在正确的工作目录
    if [ ! -f "app_refactored.rb" ]; then
        log_error "未找到app_refactored.rb文件，请检查工作目录"
        log_error "当前目录: $(pwd)"
        exit 1
    fi
    
    if [ "$1" = "development" ]; then
        log_info "开发模式启动"
        export RACK_ENV=development
        bundle exec ruby app_refactored.rb
    elif [ "$1" = "production" ]; then
        log_info "生产模式启动"
        export RACK_ENV=production
        
        # 检查puma.rb配置文件
        if [ ! -f "puma.rb" ]; then
            log_error "未找到puma.rb配置文件"
            exit 1
        fi
        
        # 使用puma启动（正确的命令格式）
        bundle exec puma -C puma.rb
    else
        log_info "默认模式启动（开发模式）"
        export RACK_ENV=development
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
    echo "  simple-install  简化安装模式（适用于网络环境差的情况）"
    echo "  fix-gems        修复Gem编译问题（解决native extension错误）"
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
    echo "  • 特别支持腾讯云OpenCloudOS系统"
    echo "  • 智能镜像源切换和故障处理"
    echo "  • 简化安装模式适应复杂网络环境"
    echo "  • 自动创建必需目录和数据库"
    echo ""
    echo "示例:"
    echo "  $0 install              # 安装依赖（包括Ruby）"
    echo "  $0 simple-install       # 简化安装（网络环境差）"
    echo "  $0 fix-gems             # 修复Gem编译问题"
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
    
    # 检查并修复Gem编译环境
    if [ -f "fix_gem_build.sh" ]; then
        log_info "运行Gem编译环境检查..."
        chmod +x fix_gem_build.sh
        ./fix_gem_build.sh deps 2>/dev/null || {
            log_warn "Gem环境检查完成，继续安装..."
        }
    fi
    
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
        simple-install)
            log_info "使用简化安装模式..."
            if grep -q "OpenCloudOS" /etc/os-release 2>/dev/null; then
                simple_install_ruby_opencloudos
            else
                log_error "简化安装模式仅支持OpenCloudOS系统"
                exit 1
            fi
            install_dependencies
            create_directories
            init_database
            log_info "简化安装完成！"
            ;;
        fix-gems)
            log_info "修复Gem编译问题..."
            if [ -f "fix_gem_build.sh" ]; then
                chmod +x fix_gem_build.sh
                ./fix_gem_build.sh
            else
                log_error "fix_gem_build.sh 文件不存在"
                exit 1
            fi
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

# 简化安装模式 - 适用于网络环境较差的情况
simple_install_ruby_opencloudos() {
    log_info "使用简化模式安装Ruby（适用于网络环境差的情况）..."
    
    # 跳过镜像源配置，直接安装基本工具
    log_info "安装最基本的开发工具..."
    
    # 只安装核心依赖
    local core_packages=("gcc" "gcc-c++" "make" "openssl-devel" "zlib-devel")
    
    for package in "${core_packages[@]}"; do
        log_info "安装 $package..."
        sudo yum install -y "$package" 2>/dev/null || {
            log_warn "$package 安装失败，尝试继续"
        }
    done
    
    # 检查核心工具
    if ! command -v gcc &>/dev/null; then
        log_error "GCC未安装，无法编译Ruby"
        return 1
    fi
    
    # 使用最简单的方式安装Ruby
    log_info "尝试编译安装Ruby（最小依赖）..."
    
    # 下载Ruby源码
    local ruby_version="3.2.0"
    local download_dir="/tmp/ruby-build"
    
    mkdir -p "$download_dir"
    cd "$download_dir"
    
    # 尝试多个下载源
    local download_urls=(
        "https://cache.ruby-china.com/pub/ruby/3.2/ruby-${ruby_version}.tar.gz"
        "https://mirrors.tuna.tsinghua.edu.cn/ruby/ruby-${ruby_version}.tar.gz"
        "https://ftp.ruby-lang.org/pub/ruby/3.2/ruby-${ruby_version}.tar.gz"
    )
    
    local downloaded=false
    for url in "${download_urls[@]}"; do
        log_info "尝试从 $url 下载Ruby源码..."
        if curl -L --connect-timeout 10 --max-time 300 -o "ruby-${ruby_version}.tar.gz" "$url" 2>/dev/null; then
            downloaded=true
            break
        else
            log_warn "下载失败，尝试下一个源"
        fi
    done
    
    if [ "$downloaded" = false ]; then
        log_error "无法下载Ruby源码，请检查网络连接"
        return 1
    fi
    
    # 解压并编译
    log_info "解压和编译Ruby..."
    tar -xzf "ruby-${ruby_version}.tar.gz"
    cd "ruby-${ruby_version}"
    
    # 配置编译选项（最小化）
    ./configure --prefix=/usr/local/ruby --disable-install-doc --disable-install-rdoc --disable-install-capi
    
    # 编译（使用单线程避免内存不足）
    make -j1
    
    # 安装
    sudo make install
    
    # 创建软链接
    sudo ln -sf /usr/local/ruby/bin/ruby /usr/local/bin/ruby
    sudo ln -sf /usr/local/ruby/bin/gem /usr/local/bin/gem
    sudo ln -sf /usr/local/ruby/bin/irb /usr/local/bin/irb
    
    # 更新PATH
    echo 'export PATH="/usr/local/ruby/bin:$PATH"' >> ~/.bashrc
    export PATH="/usr/local/ruby/bin:$PATH"
    
    # 验证安装
    if /usr/local/ruby/bin/ruby --version | grep -q "3.2"; then
        log_info "Ruby编译安装成功: $(/usr/local/ruby/bin/ruby --version)"
        return 0
    else
        log_error "Ruby编译安装失败"
        return 1
    fi
}
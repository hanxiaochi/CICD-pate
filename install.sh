#!/bin/bash
# CICD系统 - 原生安装启动脚本
# 支持多种Linux发行版和自动依赖安装
# =============================================

set -e

echo "🚀 CICD系统原生安装启动"
echo "====================================="

# 检测操作系统
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
    elif type lsb_release >/dev/null 2>&1; then
        OS=$(lsb_release -si)
        VER=$(lsb_release -sr)
    else
        OS=$(uname -s)
        VER=$(uname -r)
    fi
    echo "检测到操作系统: $OS $VER"
}

# 安装Ruby
install_ruby() {
    echo "🔧 安装Ruby..."
    
    if command -v ruby >/dev/null 2>&1; then
        RUBY_VERSION=$(ruby -v | cut -d' ' -f2)
        echo "Ruby已安装: $RUBY_VERSION"
        return 0
    fi
    
    case "$OS" in
        *"Ubuntu"*|*"Debian"*)
            sudo apt update
            sudo apt install -y ruby ruby-dev ruby-bundler sqlite3 libsqlite3-dev build-essential
            ;;
        *"CentOS"*|*"Red Hat"*|*"Rocky"*|*"AlmaLinux"*)
            sudo yum update -y
            if ! sudo yum install -y ruby ruby-devel rubygems sqlite sqlite-devel gcc gcc-c++ make; then
                echo "yum安装失败，尝试使用RVM..."
                install_ruby_via_rvm
                return $?
            fi
            ;;
        *"OpenCloudOS"*|*"Tencent"*)
            sudo yum update -y
            if ! sudo yum install -y ruby ruby-devel sqlite sqlite-devel gcc openssl-devel; then
                echo "yum安装失败，使用RVM安装..."
                install_ruby_via_rvm
                return $?
            fi
            ;;
        *)
            echo "未知系统，尝试使用RVM安装Ruby..."
            install_ruby_via_rvm
            return $?
            ;;
    esac
    
    # 配置国内镜像源
    echo "配置RubyGems国内镜像源..."
    gem sources --add https://gems.ruby-china.com/ --remove https://rubygems.org/
    
    echo "✅ Ruby安装完成"
}

# 通过RVM安装Ruby（备用方案）
install_ruby_via_rvm() {
    echo "📦 使用RVM安装Ruby..."
    
    # 安装依赖
    case "$OS" in
        *"Ubuntu"*|*"Debian"*)
            sudo apt install -y curl gnupg2 build-essential
            ;;
        *)
            sudo yum install -y curl gnupg2 gcc gcc-c++ make openssl-devel
            ;;
    esac
    
    # 安装RVM
    curl -sSL https://rvm.io/mpapis.asc | gpg2 --import -
    curl -sSL https://rvm.io/pkuczynski.asc | gpg2 --import -
    curl -sSL https://get.rvm.io | bash -s stable
    
    # 加载RVM
    source ~/.rvm/scripts/rvm
    
    # 安装Ruby
    rvm install 3.2
    rvm use 3.2 --default
    
    # 配置镜像源
    gem sources --add https://gems.ruby-china.com/ --remove https://rubygems.org/
    
    echo "✅ RVM和Ruby安装完成"
}

# 安装Gems依赖
install_gems() {
    echo "💎 安装Gem依赖..."
    
    # 基础依赖
    gem install sinatra sequel sqlite3 bcrypt json --no-document
    
    # 尝试安装完整功能依赖
    if gem install sinatra-flash haml sass --no-document; then
        echo "✅ 完整功能依赖安装成功"
        export CICD_MODE=full
    else
        echo "⚠️  部分依赖安装失败，将使用简化模式"
        export CICD_MODE=simple
    fi
    
    echo "✅ Gem依赖安装完成"
}

# 创建启动脚本
create_service() {
    echo "🔧 创建系统服务..."
    
    cat > cicd-start.sh << 'EOF'
#!/bin/bash
# CICD系统启动脚本

cd "$(dirname "$0")"

# 设置模式
export CICD_MODE=${CICD_MODE:-simple}
export RACK_ENV=production

echo "启动CICD系统 (模式: $CICD_MODE)..."
ruby app.rb
EOF
    
    chmod +x cicd-start.sh
    
    # 创建systemd服务（可选）
    if command -v systemctl >/dev/null 2>&1; then
        cat > cicd.service << EOF
[Unit]
Description=CICD System
After=network.target

[Service]
Type=simple
User=$(whoami)
WorkingDirectory=$(pwd)
ExecStart=$(pwd)/cicd-start.sh
Restart=always
Environment=CICD_MODE=$CICD_MODE

[Install]
WantedBy=multi-user.target
EOF
        
        echo "可选：sudo cp cicd.service /etc/systemd/system/ && sudo systemctl enable cicd"
    fi
    
    echo "✅ 启动脚本创建完成"
}

# 主安装流程
main() {
    detect_os
    install_ruby
    install_gems
    create_service
    
    echo ""
    echo "🎉 CICD系统安装完成！"
    echo "====================================="
    echo "启动方式："
    echo "  ./cicd-start.sh"
    echo ""
    echo "或者直接运行："
    echo "  ruby app.rb"
    echo ""
    echo "访问地址: http://localhost:4567"
    echo "默认账户: admin / admin123"
    echo ""
    echo "模式: $CICD_MODE"
    echo "====================================="
}

# 运行安装
main
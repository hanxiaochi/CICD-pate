# Ruby 3.0+ 自动安装指南

## 🚀 一键安装

本系统支持自动检测并安装Ruby 3.0+，无需手动配置。

```bash
# 克隆项目
git clone https://github.com/hanxiaochi/CICD-pate.git cicd-system
cd cicd-system

# 一键安装（自动安装Ruby和依赖）
chmod +x start_refactored.sh
./start_refactored.sh install
```

## 🔧 自动安装特性

### ✅ 支持的操作系统

- **Ubuntu/Debian**: 使用apt-get自动安装Ruby 3.2
- **CentOS/RHEL**: 使用yum安装Ruby 3.2
- **腾讯云OpenCloudOS**: 特别优化支持，自动安装依赖后使用RVM
- **Fedora**: 使用dnf安装Ruby
- **openSUSE**: 使用zypper安装Ruby
- **macOS**: 使用Homebrew安装Ruby 3.2
- **Windows**: 提供官方下载链接指导

### 🌐 国内镜像源配置

系统会自动配置以下国内镜像源以提升安装速度：

- **RubyGems源**: 
  - 优先级1: Ruby中国镜像 `https://gems.ruby-china.com/`
  - 优先级2: 清华大学镜像 `https://mirrors.tuna.tsinghua.edu.cn/rubygems/`
  - 优先级3: 阿里云镜像 `https://mirrors.aliyun.com/rubygems/`
- **Bundler源**: 自动配置对应的镜像
- **RVM Ruby源**: 多镜像备份下载
- **OpenCloudOS系统源**: 自动配置清华大学镜像
- 自动移除官方源，避免网络问题

### 🛠️ 安装内容

1. **Ruby 3.0+** - 主要运行环境
2. **Bundler** - Ruby包管理工具
3. **Build tools** - 编译依赖的构建工具
4. **项目依赖** - 自动执行`bundle install`
5. **系统目录** - 自动创建必需的工作目录

## 📋 详细安装过程

### Linux系统安装流程

```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-add-repository -y ppa:brightbox/ruby-ng
sudo apt-get install -y ruby3.2 ruby3.2-dev build-essential

# CentOS/RHEL  
sudo yum install -y centos-release-scl
sudo yum install -y rh-ruby32 rh-ruby32-ruby-devel gcc gcc-c++ make

# 腾讯云OpenCloudOS特别处理
# 系统会自动检测并配置国内镜像源，然后安装基本依赖

# 配置清华大学OpenCloudOS镜像源
cat > /etc/yum.repos.d/opencloudos-tuna.repo << 'EOF'
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

# 安装基本依赖
sudo yum install -y gcc gcc-c++ make patch
sudo yum install -y openssl-devel libffi-devel readline-devel zlib-devel
sudo yum install -y libyaml-devel sqlite-devel

# 尝试安装EPEL源（如果失败不中断）
sudo yum install -y epel-release 2>/dev/null || true

# 使用RVM安装Ruby 3.2（多镜像源备份）
curl -sSL https://mirrors.tuna.tsinghua.edu.cn/rvm/install | bash -s stable --ruby
source ~/.rvm/scripts/rvm
rvm install 3.2.0
rvm use 3.2.0 --default

# Fedora
sudo dnf install -y ruby ruby-devel gcc gcc-c++ make
```

### macOS系统安装流程

```bash
# 使用Homebrew
brew install ruby@3.2

# 配置环境变量
echo 'export PATH="/usr/local/opt/ruby@3.2/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

### Windows系统安装

系统会显示下载链接，用户需要手动下载安装：

1. 访问: https://rubyinstaller.org/downloads/
2. 下载: Ruby+Devkit 3.2.x (x64)
3. 安装后重新运行脚本

## 🔍 故障排除

### Ruby版本检查

```bash
ruby --version    # 应显示3.0+
gem --version     # 检查gem工具
bundler --version # 检查bundler
```

### 镜像源检查

```bash
gem sources -l    # 查看当前gem源
bundle config     # 查看bundler配置
```

### 常见问题

1. **权限问题**
   ```bash
   sudo chown -R $(whoami) ~/.gem
   ```

2. **网络问题/镜像源问题**
   ```bash
   # 手动配置镜像源（多个备选）
   gem sources --remove https://rubygems.org/
   
   # 尝试Ruby中国镜像
   gem sources --add https://gems.ruby-china.com/
   
   # 或者使用清华大学镜像
   gem sources --add https://mirrors.tuna.tsinghua.edu.cn/rubygems/
   
   # 或者使用阿里云镜像
   gem sources --add https://mirrors.aliyun.com/rubygems/
   
   # 验证镜像源
   gem sources -l
   curl -I https://gems.ruby-china.com/
   ```

3. **腾讯云OpenCloudOS EPEL源问题**
   ```bash
   # 手动配置清华大学镜像源
   sudo tee /etc/yum.repos.d/opencloudos-tuna.repo << 'EOF'
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
   
   sudo yum clean all
   sudo yum makecache
   ```

4. **编译问题**
   ```bash
   # 安装开发工具
   sudo apt-get install build-essential  # Ubuntu/Debian
   sudo yum groupinstall "Development Tools"  # CentOS/RHEL
   sudo yum install gcc gcc-c++ make patch  # OpenCloudOS
   ```

5. **RVM安装问题**
   ```bash
   # 手动使用清华镜像安装RVM
   curl -sSL https://mirrors.tuna.tsinghua.edu.cn/rvm/install | bash -s stable
   
   # 或者使用官方源
   curl -sSL https://get.rvm.io | bash -s stable
   
   # 重新加载环境
   source ~/.rvm/scripts/rvm
   
   # 配置Ruby下载镜像
   echo "ruby_url=https://cache.ruby-china.com/pub/ruby" > ~/.rvm/user/db
   echo "ruby_url=https://mirrors.tuna.tsinghua.edu.cn/ruby" >> ~/.rvm/user/db
   ```

## 🎯 验证安装

安装完成后，可以运行系统测试：

```bash
# 测试系统组件
ruby test_system.rb

# 启动系统
./start_refactored.sh start

# 访问系统
curl http://localhost:4567/api/health
```

## 📞 获取帮助

如果自动安装遇到问题：

1. 查看详细日志输出
2. 提交Issue: https://github.com/hanxiaochi/CICD-pate/issues
3. 包含以下信息：
   - 操作系统版本
   - Ruby版本（如果已安装）
   - 错误信息
   - 网络环境
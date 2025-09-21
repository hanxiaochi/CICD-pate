# Ruby Gem Native Extension 编译错误解决指南

## 🚨 错误症状

当运行 `bundle install` 时出现以下错误：
```
Gem::Ext::BuildError: ERROR: Failed to build gem native extension.
mkmf.rb can't find header files for ruby at /usr/share/include/ruby.h
You might have to install separate package for the ruby development environment, ruby-dev or ruby-devel
```

## 🔧 快速修复

### 方法1：使用自动修复脚本（推荐）

```bash
# 运行自动修复
./start_refactored.sh fix-gems

# 或者单独运行修复脚本
chmod +x fix_gem_build.sh
./fix_gem_build.sh
```

### 方法2：手动修复步骤

#### OpenCloudOS/CentOS/RHEL系统

```bash
# 1. 安装开发工具包
sudo yum groupinstall -y "Development Tools"

# 2. 安装Ruby开发包
sudo yum install -y ruby-devel

# 3. 安装编译依赖
sudo yum install -y gcc gcc-c++ make patch
sudo yum install -y openssl-devel libffi-devel readline-devel zlib-devel

# 4. 重新安装gems
gem update --system --no-document
gem install bundler --no-document
bundle install --retry=3 --jobs=1
```

#### Ubuntu/Debian系统

```bash
# 1. 更新包列表
sudo apt-get update

# 2. 安装Ruby开发包
sudo apt-get install -y ruby-dev build-essential

# 3. 安装编译依赖
sudo apt-get install -y libssl-dev libffi-dev libreadline-dev zlib1g-dev

# 4. 重新安装gems
gem update --system --no-document
gem install bundler --no-document
bundle install --retry=3
```

## 🔍 问题诊断

### 检查环境
```bash
# 检查Ruby版本
ruby --version

# 检查是否有Ruby头文件
find /usr/include /usr/local/include /opt -name "ruby.h" 2>/dev/null

# 检查开发工具
gcc --version
make --version

# 检查gem环境
gem env
```

### 常见问题

1. **Ruby头文件缺失**
   - 症状：`can't find header files for ruby`
   - 解决：安装 `ruby-devel` 或 `ruby-dev` 包

2. **编译工具缺失**
   - 症状：`gcc: command not found`
   - 解决：安装开发工具包

3. **内存不足**
   - 症状：编译过程中killed
   - 解决：使用单线程编译 `--jobs=1`

4. **网络超时**
   - 症状：下载gem时timeout
   - 解决：设置超时时间和重试

## 🛠️ 高级修复

### 自定义Ruby安装的修复

如果Ruby是通过源码编译安装的：

```bash
# 检查Ruby安装路径
ruby_path=$(ruby -e "puts RbConfig::CONFIG['prefix']")
echo "Ruby安装路径: $ruby_path"

# 设置头文件路径
export C_INCLUDE_PATH="$ruby_path/include:$C_INCLUDE_PATH"
export CPLUS_INCLUDE_PATH="$ruby_path/include:$CPLUS_INCLUDE_PATH"

# 重新编译gems
bundle install
```

### 清理并重建gem环境

```bash
# 清理所有gems
gem cleanup
gem uninstall bundler -a -x
rm -rf ~/.bundle
rm -rf vendor/bundle

# 重新安装
gem install bundler --no-document
bundle config set --global jobs 1
bundle install --retry=3
```

## 📋 预防措施

### 完整的开发环境安装

```bash
# OpenCloudOS/CentOS/RHEL
sudo yum groupinstall -y "Development Tools"
sudo yum install -y ruby-devel openssl-devel libffi-devel readline-devel zlib-devel libyaml-devel sqlite-devel

# Ubuntu/Debian
sudo apt-get install -y build-essential ruby-dev libssl-dev libffi-dev libreadline-dev zlib1g-dev libyaml-dev libsqlite3-dev

# Fedora
sudo dnf install -y ruby-devel gcc gcc-c++ make openssl-devel libffi-devel readline-devel zlib-devel
```

### Bundle配置优化

```bash
# 配置单线程编译（适合小内存服务器）
bundle config set --global jobs 1

# 配置编译选项
bundle config set --global build.bigdecimal --with-cflags="-O2 -g -pipe"

# 配置超时和重试
export BUNDLE_TIMEOUT=300
export BUNDLE_RETRY=3
```

## 🔄 如果修复失败

1. **检查系统资源**
   ```bash
   free -h  # 检查内存
   df -h    # 检查磁盘空间
   ```

2. **查看详细错误**
   ```bash
   bundle install --verbose
   ```

3. **手动编译单个gem**
   ```bash
   gem install bigdecimal --no-document --verbose
   ```

4. **使用系统Ruby**
   ```bash
   # 如果自定义安装的Ruby有问题，尝试系统Ruby
   sudo yum install -y ruby ruby-devel
   ```

## 📞 获取帮助

如果上述方法都无法解决问题：

1. **运行诊断脚本**
   ```bash
   ./fix_gem_build.sh check
   ```

2. **提交Issue**
   - 仓库地址：https://github.com/hanxiaochi/CICD-pate/issues
   - 包含系统信息、Ruby版本、错误日志

3. **提供信息**
   - 操作系统版本：`cat /etc/os-release`
   - Ruby版本：`ruby --version`
   - 完整错误日志

---

**提示**: 大多数gem编译问题都是由于缺少开发包或头文件引起的。使用 `./start_refactored.sh fix-gems` 命令通常能解决90%的问题。
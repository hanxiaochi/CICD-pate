# 腾讯云OpenCloudOS系统安装故障排除指南

## 🚨 常见问题快速解决

### 问题1：镜像源404错误

**错误信息**：
```
Errors during downloading metadata for repository 'tuna-opencloudos-base':
Status code: 404 for https://mirrors.tuna.tsinghua.edu.cn/opencloudos/...
```

**解决方案**：
1. 使用简化安装模式（推荐）：
```bash
./start_refactored.sh simple-install
```

2. 或者手动跳过镜像源配置：
```bash
# 跳过镜像源配置，直接安装基本工具
sudo yum install -y gcc gcc-c++ make openssl-devel zlib-devel

# 然后手动编译安装Ruby
cd /tmp
curl -L https://cache.ruby-china.com/pub/ruby/3.2/ruby-3.2.0.tar.gz -o ruby-3.2.0.tar.gz
tar -xzf ruby-3.2.0.tar.gz
cd ruby-3.2.0
./configure --prefix=/usr/local/ruby --disable-install-doc
make && sudo make install
```

### 问题2：EPEL源安装失败

**错误信息**：
```
No match for argument: epel-release
```

**解决方案**：
- 这是正常情况，脚本会自动跳过EPEL安装，不会影响Ruby安装
- 继续执行即可，系统会使用RVM安装Ruby

### 问题3：RVM安装失败

**解决方案**：
1. 使用简化安装模式：
```bash
./start_refactored.sh simple-install
```

2. 手动安装Ruby（离线方式）：
```bash
# 下载Ruby源码包（如果网络连接有问题，可先在其他机器下载后传输）
wget https://cache.ruby-china.com/pub/ruby/3.2/ruby-3.2.0.tar.gz

# 安装基本依赖
sudo yum install -y gcc gcc-c++ make openssl-devel

# 编译安装
tar -xzf ruby-3.2.0.tar.gz
cd ruby-3.2.0
./configure --prefix=/usr/local/ruby
make -j1  # 使用单线程编译（避免内存不足）
sudo make install

# 配置环境变量
echo 'export PATH="/usr/local/ruby/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

### 问题4：网络连接超时

**解决方案**：
1. 检查网络连接：
```bash
ping mirrors.aliyun.com
curl -I https://cache.ruby-china.com
```

2. 如果网络正常但下载慢，增加超时时间：
```bash
export CURL_TIMEOUT=300  # 5分钟超时
./start_refactored.sh install
```

3. 使用本地源码安装（见问题3的手动安装方法）

## 🔧 系统兼容性

### OpenCloudOS 9.x
- ✅ 完全支持
- 推荐使用简化安装模式

### TencentOS Server
- ✅ 支持
- 使用标准CentOS安装方法

### 其他发行版
- 请参考主README文档中的安装指南

## 📋 安装验证

安装完成后验证：
```bash
# 检查Ruby版本
ruby --version

# 检查gem工具
gem --version

# 测试安装依赖
bundle install

# 启动系统
./start_refactored.sh start
```

## 🆘 获取帮助

如果以上方法都无法解决问题：

1. 运行诊断命令：
```bash
# 系统信息
cat /etc/os-release
uname -a

# 网络测试
curl -I https://cache.ruby-china.com
ping -c 3 mirrors.aliyun.com

# 依赖检查
which gcc make curl
```

2. 提交Issue：
   - 仓库地址：https://github.com/hanxiaochi/CICD-pate/issues
   - 包含上述诊断信息和详细错误日志

## 💡 性能优化建议

### 腾讯云服务器优化
1. 选择较大内存的实例（推荐2GB+）
2. 使用SSD云盘提升IO性能
3. 配置腾讯云内网镜像源（如果可用）

### 编译优化
```bash
# 单线程编译（内存小于2GB时推荐）
make -j1

# 多线程编译（内存充足时）
make -j$(nproc)

# 减少编译输出
make --quiet
```

---

**最后更新**: 2025-09-21  
**适用版本**: CICD系统 v2.0+
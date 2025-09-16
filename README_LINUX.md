# CICD工具Linux版安装指南

## 概述

本指南提供了如何在Linux服务器上安装和运行CICD自动化部署工具的详细步骤。

## 系统要求

- Linux操作系统（Ubuntu、Debian、CentOS、RHEL等）
- Ruby 3.0或更高版本
- RubyGems包管理器
- Git客户端
- SSH客户端
- 网络连接

## 安装步骤

### 1. 安装Ruby环境

**Ubuntu/Debian:**
```bash
sudo apt-get update
sudo apt-get install ruby-full git -y
```

**CentOS/RHEL:**
```bash
sudo yum install ruby git -y
```

**验证安装:**
```bash
ruby --version
gem --version
git --version
```

### 2. 安装项目依赖

首先，确保您已进入项目目录：
```bash
cd /path/to/your/project/hxc
```

然后，运行以下命令安装项目依赖：
```bash
# 确保有执行权限
chmod +x start.sh

# 运行启动脚本（会自动安装依赖）
./start.sh
```

如果需要手动安装依赖：
```bash
gem install bundler
bundle install
```

### 3. 配置应用

默认配置已经设置为适合Linux环境运行，但您可能需要根据自己的需求修改一些配置：

- 端口设置：默认为4567，可以在app.rb文件中的`set :port, 4567`修改
- 绑定地址：默认为0.0.0.0，允许从任何IP访问
- 会话密钥：建议修改app.rb中的`set :session_secret, 'your_secret_key'`为更安全的值

### 4. 启动应用

**开发模式启动（控制台运行）：**
```bash
./start.sh
```

**后台模式启动：**
```bash
# 修改start.sh文件，取消后台运行代码的注释
# 或者直接运行以下命令
nohup ruby app.rb > cicd.log 2>&1 &
```

**使用Systemd管理（推荐生产环境）：**

创建服务文件：`sudo nano /etc/systemd/system/cicd.service`

```ini
[Unit]
Description=CICD自动化部署工具
After=network.target

[Service]
Type=simple
User=your_username
WorkingDirectory=/path/to/your/project/hxc
ExecStart=/usr/bin/ruby app.rb
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

启用并启动服务：
```bash
sudo systemctl daemon-reload
sudo systemctl enable cicd
sudo systemctl start cicd
```

查看服务状态：
```bash
sudo systemctl status cicd
```

### 5. 访问应用

打开浏览器，访问以下地址：
```
http://your_server_ip:4567
```

使用默认账号登录：
- 用户名：admin
- 密码：admin123

## 常见问题解决

### 端口占用问题

如果4567端口已被占用，可以修改app.rb中的端口设置：
```ruby
set :port, 8080  # 或其他未被占用的端口
```

### 权限问题

如果遇到文件操作权限问题，请确保当前用户有足够的权限：
```bash
# 为项目目录设置适当的权限
sudo chown -R your_username:your_username /path/to/your/project/hxc
sudo chmod -R 755 /path/to/your/project/hxc
```

### SSH连接问题

确保您的服务器上已安装SSH客户端，并且目标服务器允许SSH连接：
```bash
# 安装SSH客户端
sudo apt-get install openssh-client -y  # Ubuntu/Debian
sudo yum install openssh-clients -y    # CentOS/RHEL
```

### 备份和部署路径权限

确保设置的备份路径和部署路径有正确的读写权限：
```bash
# 为备份目录设置权限
sudo mkdir -p /path/to/backup
sudo chown -R your_username:your_username /path/to/backup
sudo chmod -R 755 /path/to/backup
```

## 安全建议

1. **修改默认密码**：登录后立即修改管理员密码
2. **设置防火墙**：限制对4567端口的访问，只允许可信IP访问
3. **使用HTTPS**：在生产环境中，建议配置HTTPS
4. **定期备份数据库**：cicd.db文件包含所有项目和部署信息

## 卸载指南

如需卸载应用，只需删除项目目录：
```bash
rm -rf /path/to/your/project/hxc
```

如果创建了Systemd服务，也需要删除：
```bash
sudo systemctl stop cicd
sudo systemctl disable cicd
sudo rm /etc/systemd/system/cicd.service
sudo systemctl daemon-reload
```
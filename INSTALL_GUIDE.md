# Ruby环境安装指南

本指南将帮助您在Windows系统上安装Ruby环境，以便运行CICD自动化部署工具。

## 自动安装方法

1. 找到我们为您创建的`install_ruby.bat`文件（位于项目根目录）
2. **重要**：右键点击该文件，选择"以管理员身份运行"
3. 脚本将自动执行以下操作：
   - 检查系统是否已安装Ruby
   - 下载Ruby 3.2.2安装程序（如果未安装）
   - 运行安装向导
   - 安装bundler gem

4. 安装过程中，请确保勾选以下选项：
   - Add Ruby executables to your PATH（将Ruby可执行文件添加到PATH环境变量）
   - Associate .rb and .rbw files with this Ruby installation（将.rb和.rbw文件关联到此Ruby安装）

## 手动安装方法（如果自动安装失败）

1. 访问RubyInstaller官网：https://rubyinstaller.org/downloads/
2. 下载最新的Ruby+Devkit版本（建议3.0以上版本）
3. 运行安装程序，按照向导完成安装
4. 打开命令提示符（cmd）或PowerShell
5. 安装bundler：
   ```
   gem install bundler
   ```

## 验证安装

安装完成后，打开命令提示符或PowerShell，执行以下命令验证安装是否成功：

```
ruby --version
bundle --version
```

如果显示版本号，则表示安装成功。

## 启动CICD工具

1. 安装完成Ruby后，返回项目目录
2. 双击运行`start.bat`脚本
3. 脚本将自动：
   - 安装项目依赖
   - 启动CICD工具服务

4. 打开浏览器，访问 http://localhost:4567
5. 使用默认账号登录：
   - 用户名：admin
   - 密码：admin123
   - **首次登录后请及时修改密码**

## 常见问题解决

### 问题1：命令提示符中无法识别ruby命令

**解决方法**：
- 确认安装时勾选了"Add Ruby executables to your PATH"
- 重启命令提示符或PowerShell
- 手动添加Ruby安装目录到系统环境变量PATH中

### 问题2：gem install bundler 命令执行失败

**解决方法**：
- 检查网络连接
- 尝试使用国内镜像源：
  ```
  gem sources --add https://gems.ruby-china.com/ --remove https://rubygems.org/
  gem install bundler
  ```

### 问题3：bundle install 速度慢或失败

**解决方法**：
- 配置bundler使用国内镜像源：
  ```
  bundle config mirror.https://rubygems.org https://gems.ruby-china.com
  ```
- 然后再次尝试：
  ```
  bundle install
  ```

## 联系方式

如果您在安装过程中遇到任何问题，请随时联系我们获取帮助。

祝您使用愉快！
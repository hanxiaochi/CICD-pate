# config.ru - Rack配置文件
# 这个文件告诉Puma如何启动Ruby应用

# 设置工作目录
require 'fileutils'
Dir.chdir File.dirname(__FILE__)

# 加载应用程序
require_relative 'app_refactored'

# 运行应用
run CicdApp
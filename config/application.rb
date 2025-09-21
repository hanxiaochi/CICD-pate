# 简化的应用程序配置 - 解决数据库加载顺序问题
require 'sinatra'
require 'sinatra/flash'
require 'haml'
require 'sequel'
require 'bcrypt'
require 'fileutils'
require 'json'
require 'net/ssh'
require 'websocket-eventmachine-server'

# 1. 立即初始化数据库连接
puts "正在连接数据库..."
begin
  database = Sequel.sqlite('cicd.db')
  Object.const_set('DB', database) unless defined?(DB)
  Sequel::Model.db = database
  
  # 测试连接
  database.test_connection
  puts "✓ 数据库连接成功"
rescue => e
  puts "✗ 数据库连接失败: #{e.message}"
  exit 1
end

# 2. 加载基础服务（这些不依赖模型）
puts "正在加载基础服务..."
require_relative '../lib/utils/database_initializer'

# 3. 加载模型类（现在数据库已经可用）
puts "正在加载模型类..."
begin
  require_relative '../lib/models/user'
  require_relative '../lib/models/project'
  require_relative '../lib/models/workspace'
  require_relative '../lib/models/resource'
  require_relative '../lib/models/build'
  require_relative '../lib/models/deployment'
  require_relative '../lib/models/log'
  require_relative '../lib/models/system_config'
  require_relative '../lib/models/permission'
  puts "✓ 模型加载成功"
rescue => e
  puts "✗ 模型加载失败: #{e.message}"
  puts "错误位置: #{e.backtrace.first(3).join('\n')}"
  exit 1
end

# 4. 加载服务类（这些依赖模型）
puts "正在加载服务类..."
require_relative '../lib/services/log_service'
require_relative '../lib/services/permission_service'

# 5. 加载中间件
require_relative '../lib/middleware/logging_middleware'
require_relative '../lib/middleware/permission_middleware'
require_relative '../lib/middleware/security_middleware'

# 6. 加载控制器类
require_relative '../lib/controllers/base_controller'
require_relative '../lib/controllers/api_controller'
require_relative '../lib/controllers/auth_controller'
require_relative '../lib/controllers/workspace_controller'
require_relative '../lib/controllers/asset_controller'
require_relative '../lib/controllers/system_controller'

# 7. 加载插件
require_relative '../lib/plugins/notification_plugin'
require_relative '../lib/plugins/git_plugin'

puts "✓ 所有组件加载完成"

# 应用程序配置类
class ApplicationConfig
  def self.load_config
    config_path = File.join(File.dirname(__FILE__), '../config.json')
    if File.exist?(config_path)
      JSON.parse(File.read(config_path))
    else
      {
        "app_port" => 4567,
        "log_level" => "info",
        "temp_dir" => "./tmp",
        "ssh_default_port" => 22,
        "docker_support" => true,
        "websocket_port" => 8080
      }
    end
  end

  def self.initialize_database
    # 数据库连接已经在加载时建立，这里只初始化表结构
    puts "正在初始化数据库表结构..."
    DatabaseInitializer.create_tables
    puts "✓ 数据库初始化完成"
  end

  def self.configure_sinatra(app)
    app.configure do
      app.set :bind, '0.0.0.0'
      app.set :port, CONFIG['app_port']
      app.set :views, './views'
      app.set :public_folder, './public'
      app.enable :sessions
      app.set :session_secret, 'cicd_system_secret_key'
    end
  end
end

# 全局配置
CONFIG = ApplicationConfig.load_config

puts "=== 配置加载完成 ==="
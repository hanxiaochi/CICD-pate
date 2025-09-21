# 应用程序配置
require 'sinatra'
require 'sinatra/flash'
require 'haml'
require 'sequel'
require 'bcrypt'
require 'fileutils'
require 'json'
require 'net/ssh'
require 'websocket-eventmachine-server'

# 按正确顺序加载库文件
# 1. 首先加载基础类和服务
require_relative '../lib/services/log_service'
require_relative '../lib/services/permission_service'
require_relative '../lib/utils/database_initializer'

# 2. 加载中间件
require_relative '../lib/middleware/logging_middleware'
require_relative '../lib/middleware/permission_middleware'
require_relative '../lib/middleware/security_middleware'

# 3. 加载模型类（按依赖关系排序）
require_relative '../lib/models/user'
require_relative '../lib/models/project'
require_relative '../lib/models/workspace'
require_relative '../lib/models/resource'
require_relative '../lib/models/build'
require_relative '../lib/models/deployment'
require_relative '../lib/models/log'
require_relative '../lib/models/system_config'
require_relative '../lib/models/permission'

# 4. 加载控制器类（基础控制器必须先加载）
require_relative '../lib/controllers/base_controller'
require_relative '../lib/controllers/api_controller'
require_relative '../lib/controllers/auth_controller'
require_relative '../lib/controllers/workspace_controller'
require_relative '../lib/controllers/asset_controller'
require_relative '../lib/controllers/system_controller'

# 5. 加载插件
require_relative '../lib/plugins/notification_plugin'
require_relative '../lib/plugins/git_plugin'

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
    # 使用局部变量避免动态常量分配问题
    database = Sequel.sqlite('cicd.db')
    
    # 将数据库实例设置为全局常量
    Object.const_set('DB', database) unless defined?(DB)
    
    # 初始化所有数据表
    DatabaseInitializer.create_tables
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
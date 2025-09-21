# 应用程序配置 V2 - 彻底解决数据库初始化问题
require 'sinatra'
require 'sinatra/flash'
require 'haml'
require 'sequel'
require 'bcrypt'
require 'fileutils'
require 'json'
require 'net/ssh'

puts "=== CICD 系统启动 V2 ==="

# 第一步：强制初始化数据库连接
puts "1. 初始化数据库连接..."
begin
  # 确保数据库文件目录存在
  FileUtils.mkdir_p(File.dirname('./cicd.db'))
  
  # 创建数据库连接
  DB = Sequel.sqlite('./cicd.db', max_connections: 1) unless defined?(DB)
  
  # 设置 Sequel 默认数据库
  Sequel::Model.db = DB
  
  # 测试连接
  DB.test_connection
  puts "✓ 数据库连接成功"
rescue => e
  puts "✗ 数据库连接失败: #{e.message}"
  exit 1
end

# 第二步：立即创建必要的数据库表
puts "2. 创建数据库表..."
begin
  # 用户表
  unless DB.table_exists?(:users)
    DB.create_table :users do
      primary_key :id
      String :username, null: false, unique: true
      String :password_hash, null: false
      String :role, default: 'user'
      String :email
      String :phone
      String :department
      Boolean :active, default: true
      Time :last_login
      Time :created_at, default: Time.now
      Time :updated_at, default: Time.now
    end
    puts "✓ 创建 users 表"
  end

  # 工作空间表
  unless DB.table_exists?(:workspaces)
    DB.create_table :workspaces do
      primary_key :id
      String :name, null: false, unique: true
      String :description
      Integer :owner_id, null: false
      Boolean :active, default: true
      Time :created_at, default: Time.now
      Time :updated_at, default: Time.now
    end
    puts "✓ 创建 workspaces 表"
  end

  # 项目表
  unless DB.table_exists?(:projects)
    DB.create_table :projects do
      primary_key :id
      String :name, null: false
      String :project_type, default: 'java'
      String :repo_type, null: false
      String :repo_url, null: false
      String :branch, default: 'master'
      String :build_script
      String :artifact_path
      String :deploy_server
      String :deploy_path
      String :start_script
      String :stop_script
      String :backup_path
      String :start_mode, default: 'default'
      String :stop_mode, default: 'sh_script'
      String :jvm_options
      String :environment_vars
      Boolean :auto_start, default: false
      Integer :user_id
      Integer :workspace_id
      Time :created_at, default: Time.now
      Time :updated_at, default: Time.now
    end
    puts "✓ 创建 projects 表"
  end

  # 资源表
  unless DB.table_exists?(:resources)
    DB.create_table :resources do
      primary_key :id
      String :name, null: false
      String :ip, null: false
      Integer :ssh_port, default: 22
      String :username
      String :password_hash
      String :ssh_key_path
      String :description
      String :os_type, default: 'linux'
      String :status, default: 'online'
      Time :last_check
      Time :created_at, default: Time.now
      Time :updated_at, default: Time.now
    end
    puts "✓ 创建 resources 表"
  end

  # 构建表
  unless DB.table_exists?(:builds)
    DB.create_table :builds do
      primary_key :id
      Integer :project_id, null: false
      String :build_number
      String :commit_id
      String :branch
      String :status, default: 'pending'
      String :build_log
      String :artifact_path
      Time :start_time
      Time :end_time
      Integer :duration
      Integer :user_id
      Time :created_at, default: Time.now
    end
    puts "✓ 创建 builds 表"
  end

  # 部署表
  unless DB.table_exists?(:deployments)
    DB.create_table :deployments do
      primary_key :id
      Integer :project_id, null: false
      Integer :build_id
      String :version
      String :status, default: 'pending'
      String :deploy_log
      Time :start_time
      Time :end_time
      Integer :duration
      Integer :user_id
      Time :created_at, default: Time.now
    end
    puts "✓ 创建 deployments 表"
  end

  # 日志表
  unless DB.table_exists?(:logs)
    DB.create_table :logs do
      primary_key :id
      String :log_type
      String :level
      String :message
      String :source
      Integer :user_id
      Integer :project_id
      String :ip_address
      Time :created_at, default: Time.now
    end
    puts "✓ 创建 logs 表"
  end

  # 权限表
  unless DB.table_exists?(:permissions)
    DB.create_table :permissions do
      primary_key :id
      Integer :user_id, null: false
      String :resource_type
      Integer :resource_id
      String :permission_type
      Time :created_at, default: Time.now
    end
    puts "✓ 创建 permissions 表"
  end

  # 系统配置表
  unless DB.table_exists?(:system_configs)
    DB.create_table :system_configs do
      primary_key :id
      String :config_key, null: false, unique: true
      String :config_value
      String :config_type, default: 'string'
      String :description
      Boolean :is_system, default: false
      Time :created_at, default: Time.now
      Time :updated_at, default: Time.now
    end
    puts "✓ 创建 system_configs 表"
  end

  puts "✓ 所有数据库表创建完成"
rescue => e
  puts "✗ 数据库表创建失败: #{e.message}"
  puts "错误详情: #{e.backtrace.first(3).join('\n')}"
  exit 1
end

# 第三步：创建默认数据
puts "3. 创建默认数据..."
begin
  # 创建默认管理员
  unless DB[:users].where(username: 'admin').count > 0
    DB[:users].insert(
      username: 'admin',
      password_hash: BCrypt::Password.create('admin123'),
      role: 'admin',
      email: 'admin@example.com',
      created_at: Time.now,
      updated_at: Time.now
    )
    puts "✓ 创建默认管理员账户"
  end

  # 创建默认工作空间
  unless DB[:workspaces].where(name: 'default').count > 0
    admin_user = DB[:users].where(username: 'admin').first
    if admin_user
      DB[:workspaces].insert(
        name: 'default',
        description: '默认工作空间',
        owner_id: admin_user[:id],
        created_at: Time.now,
        updated_at: Time.now
      )
      puts "✓ 创建默认工作空间"
    end
  end

  # 创建系统配置
  default_configs = [
    {
      config_key: 'app_name',
      config_value: 'CICD自动化部署系统',
      config_type: 'string',
      description: '应用程序名称',
      is_system: true
    },
    {
      config_key: 'app_version',
      config_value: '2.0.0',
      config_type: 'string',
      description: '应用程序版本',
      is_system: true
    }
  ]

  default_configs.each do |config|
    unless DB[:system_configs].where(config_key: config[:config_key]).count > 0
      DB[:system_configs].insert(config.merge(created_at: Time.now, updated_at: Time.now))
    end
  end
  puts "✓ 创建默认系统配置"

rescue => e
  puts "✗ 默认数据创建失败: #{e.message}"
  # 不退出，继续运行
end

# 第四步：定义简化的模型类
puts "4. 定义模型类..."

# 用户模型
class User < Sequel::Model(:users)
  plugin :timestamps, update_on_create: true
  
  def to_hash
    {
      id: id,
      username: username,
      role: role,
      email: email,
      active: active,
      created_at: created_at,
      updated_at: updated_at
    }
  end
  
  def admin?
    role == 'admin'
  end
end

# 项目模型
class Project < Sequel::Model(:projects)
  plugin :timestamps, update_on_create: true
  many_to_one :user
  many_to_one :workspace
end

# 工作空间模型
class Workspace < Sequel::Model(:workspaces)
  plugin :timestamps, update_on_create: true
  one_to_many :projects
  many_to_one :user, key: :owner_id
end

# 其他基础模型
class Resource < Sequel::Model(:resources)
  plugin :timestamps, update_on_create: true
end

class Build < Sequel::Model(:builds)
  plugin :timestamps, update_on_create: true
  many_to_one :project
  many_to_one :user
end

class Deployment < Sequel::Model(:deployments)
  plugin :timestamps, update_on_create: true
  many_to_one :project
  many_to_one :user
  many_to_one :build
end

class Log < Sequel::Model(:logs)
  plugin :timestamps, update_on_create: true
  many_to_one :user
  many_to_one :project
end

class Permission < Sequel::Model(:permissions)
  plugin :timestamps, update_on_create: true
  many_to_one :user
end

class SystemConfig < Sequel::Model(:system_configs)
  plugin :timestamps, update_on_create: true
end

puts "✓ 模型类定义完成"

# 第五步：应用程序配置
class ApplicationConfig
  def self.load_config
    {
      "app_port" => 4567,
      "log_level" => "info",
      "temp_dir" => "./tmp",
      "ssh_default_port" => 22,
      "docker_support" => true,
      "websocket_port" => 8080
    }
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

puts "=== 系统初始化完成 ==="
puts "数据库: SQLite (cicd.db)"
puts "端口: #{CONFIG['app_port']}"
puts "管理员账户: admin / admin123"
puts "=================================="
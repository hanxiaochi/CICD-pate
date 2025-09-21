# --- 配置和初始化 ---
require 'sinatra'
require 'sinatra/flash'
require 'haml'
require 'sequel'
require 'bcrypt'
require 'git'
require 'net/sftp'
require 'net/ssh'
require 'fileutils'
require 'json'
require 'time'

# 读取配置文件
def load_config
  config_path = File.join(File.dirname(__FILE__), 'config.json')
  if File.exist?(config_path)
    JSON.parse(File.read(config_path))
  else
    {
      "ssh_default_port" => 22,
      "app_port" => 4567,
      "log_level" => "info",
      "temp_dir" => "./tmp",
      "docker_support" => true
    }
  end
end

CONFIG = load_config

# 配置Sinatra应用
configure do
  set :bind, '0.0.0.0'
  set :port, CONFIG['app_port'] || 4567
  set :views, './views'
  set :public_folder, './public'
  enable :sessions
  set :session_secret, 'cicd_tools_secret_key'

  Encoding.default_external = Encoding::UTF_8
  Encoding.default_internal = Encoding::UTF_8
end

# 初始化数据库
DB = Sequel.sqlite('cicd.db')

# 确保必要的数据库表存在
unless DB.table_exists?(:projects)
  DB.create_table :projects do
    primary_key :id
    String :name, :unique => true, :null => false
    String :repo_type, :null => false
    String :repo_url, :null => false
    String :branch, :default => 'master'
    String :build_script
    String :artifact_path
    String :deploy_server
    String :deploy_path
    String :start_script
    String :backup_path
    String :start_mode, :default => 'default'
    String :stop_mode, :default => 'sh_script'
    String :docker_compose_file, :default => ''
    String :start_type, :default => 'script_path'
    Time :created_at, :default => Time.now
    Time :updated_at, :default => Time.now
  end
end

unless DB.table_exists?(:deployments)
  DB.create_table :deployments do
    primary_key :id
    foreign_key :project_id, :projects, :null => false
    String :version
    String :status, :default => 'pending'
    String :backup_file
    Time :deployed_at
    String :deploy_user
    Text :log
  end
end

unless DB.table_exists?(:users)
  DB.create_table :users do
    primary_key :id
    String :username, :unique => true, :null => false
    String :password_hash, :null => false
    String :role, :default => 'user'
    Time :created_at, :default => Time.now
  end
  password_hash = BCrypt::Password.create('admin123')
  DB[:users].insert(:username => 'admin', :password_hash => password_hash, :role => 'admin')
end

# --- 模型定义 ---
class Project < Sequel::Model(:projects)
  one_to_many :deployments
  def before_save
    self.updated_at = Time.now
    super
  end
end

class Deployment < Sequel::Model(:deployments)
  many_to_one :project
end

class User < Sequel::Model(:users)
  def authenticate(password)
    BCrypt::Password.new(password_hash) == password
  end
end

# --- 辅助方法 ---
helpers do
  def current_user
    if session[:user_id]
      @current_user ||= User[session[:user_id]]
    end
  end

  def login_required
    unless current_user
      session[:redirect_to] = request.path_info
      flash[:error] = '请先登录'
      redirect '/login'
    end
  end

  def admin_required
    unless current_user && current_user.role == 'admin'
      flash[:error] = '需要管理员权限'
      redirect '/'
    end
  end

  def execute_command(cmd)
    output = `#{cmd} 2>&1`
    { :output => output, :success => $?.success? }
  end
end

# --- 路由定义 ---

## 用户认证相关路由
get '/login' do
  haml :login
end

post '/login' do
  user = User.find(:username => params[:username])
  if user && user.authenticate(params[:password])
    session[:user_id] = user.id
    redirect session[:redirect_to] || '/'
  else
    flash[:error] = '用户名或密码错误'
    redirect '/login'
  end
end

get '/logout' do
  session.clear
  flash[:success] = '已成功退出登录'
  redirect '/login'
end

## 项目管理相关路由
get '/projects/new' do
  login_required
  @project = Project.new
  haml :project_form
end

post '/projects' do
  login_required
  # 处理项目创建逻辑
end

get '/projects/:id/edit' do
  login_required
  @project = Project[params[:id]]
  haml :project_form
end

post '/projects/:id' do
  login_required
  # 处理项目更新逻辑
end

get '/projects/:id/delete' do
  login_required
  # 处理项目删除逻辑
end

## 部署管理相关路由
get '/projects/:id/deploy' do
  login_required
  @project = Project[params[:id]]
  haml :deploy
end

post '/projects/:id/deploy' do
  login_required
  # 处理部署逻辑
end

## Docker操作相关路由
get '/projects/:id/docker/start' do
  login_required
  # 处理Docker启动逻辑
end

get '/projects/:id/docker/stop' do
  login_required
  # 处理Docker停止逻辑
end

get '/projects/:id/docker/restart' do
  login_required
  # 处理Docker重启逻辑
end

get '/' do
  login_required
  haml :index
end

# --- 创建所需目录 ---
required_dirs = ['./views', './public', './tmp']
required_dirs.each do |dir|
  FileUtils.mkdir_p(dir) unless File.directory?(dir) # 修复 Dir.mkdir_p 为 FileUtils.mkdir_p
end
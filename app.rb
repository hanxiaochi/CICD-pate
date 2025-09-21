# --- 配置和初始化 ---
require 'sinatra'
require 'sinatra/flash'
require 'haml'
require 'sequel'
require 'bcrypt'
require 'fileutils'
require 'json'

# 读取配置文件
def load_config
  config_path = File.join(File.dirname(__FILE__), 'config.json')
  if File.exist?(config_path)
    JSON.parse(File.read(config_path))
  else
    {
      "app_port" => 4567,
      "log_level" => "info",
      "temp_dir" => "./tmp"
    }
  end
end

CONFIG = load_config

# 配置Sinatra应用
configure do
  set :bind, '0.0.0.0'
  set :port, CONFIG['app_port']
  set :views, './views'
  set :public_folder, './public'
  enable :sessions
  set :session_secret, 'cicd_tools_secret_key'
end

# 初始化数据库
DB = Sequel.sqlite('cicd.db')

# --- 模型定义 ---
class Project < Sequel::Model(:projects); end
class Resource < Sequel::Model(:resources); end
class Service < Sequel::Model(:services); end
class User < Sequel::Model(:users)
  def authenticate(password)
    BCrypt::Password.new(password_hash) == password
  end
end

# --- 辅助方法 ---
helpers do
  def current_user
    @current_user ||= User[session[:user_id]] if session[:user_id]
  end

  def login_required
    redirect '/login' unless current_user
  end

  def admin_required
    redirect '/' unless current_user&.role == 'admin'
  end
end

# --- 路由定义 ---

## 用户认证
get '/login' do
  haml :login
end

post '/login' do
  user = User.find(username: params[:username])
  if user&.authenticate(params[:password])
    session[:user_id] = user.id
    redirect '/'
  else
    flash[:error] = '用户名或密码错误'
    redirect '/login'
  end
end

get '/logout' do
  session.clear
  redirect '/login'
end

## 项目管理
get '/projects' do
  login_required
  @projects = Project.all
  haml :projects
end

get '/projects/new' do
  login_required
  haml :project_form
end

post '/projects' do
  login_required
  Project.create(params)
  redirect '/projects'
end

## 资源管理
get '/resources' do
  login_required
  @resources = Resource.all
  haml :resources
end

post '/resources' do
  login_required
  Resource.create(params)
  redirect '/resources'
end

## 服务管理
get '/services' do
  login_required
  @services = Service.all
  haml :services
end

post '/services/restart' do
  login_required
  service = Service[params[:id]]
  `systemctl restart #{service.name}`
  redirect '/services'
end

## 管理员页面
get '/admin' do
  admin_required
  @users = User.all
  haml :admin
end

post '/admin/users' do
  admin_required
  User.create(
    username: params[:username],
    password_hash: BCrypt::Password.create(params[:password]),
    role: params[:role]
  )
  redirect '/admin'
end

# --- 创建所需目录 ---
required_dirs = ['./views', './public', './tmp']
required_dirs.each do |dir|
  FileUtils.mkdir_p(dir) unless File.directory?(dir)
end
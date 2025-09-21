# 主应用程序 - 简化版本
require_relative 'config/application_v2'

# 启动时间记录
STARTUP_TIME = Time.now.to_i

# 简化的基础控制器
class BaseController
  def initialize(app)
    @app = app
  end

  def current_user
    @current_user ||= User[session[:user_id]] if session[:user_id]
  end

  def json_response(data, status = 200)
    content_type :json
    status status
    data.to_json
  end

  def success_response(message = '操作成功', data = nil)
    json_response({
      success: true,
      message: message,
      data: data,
      timestamp: Time.now.to_i
    })
  end
end

# 主应用程序类
class CicdApp < Sinatra::Base
  register Sinatra::Flash
  
  ApplicationConfig.configure_sinatra(self)
  
  helpers do
    def current_user
      @current_user ||= User[session[:user_id]] if session[:user_id]
    end

    def login_required
      redirect '/login' unless current_user
    end

    def json_response(data, status = 200)
      content_type :json
      status status
      data.to_json
    end

    def success_response(message = '操作成功', data = nil)
      json_response({
        success: true,
        message: message,
        data: data,
        timestamp: Time.now.to_i
      })
    end
  end

  # === 基础路由 ===
  
  # 首页
  get '/' do
    login_required
    @projects = Project.limit(10).all
    @users = User.count
    @system_info = {
      app_name: 'CICD自动化部署系统',
      version: '2.0.0',
      uptime: Time.now.to_i - STARTUP_TIME
    }
    
    erb :index
  end

  # 登录页面
  get '/login' do
    erb :login
  end

  # 登录处理
  post '/login' do
    username = params[:username]
    password = params[:password]
    
    user = User.where(username: username).first
    
    if user && BCrypt::Password.new(user.password_hash) == password
      session[:user_id] = user.id
      user.update(last_login: Time.now)
      
      if request.accept.include?('application/json')
        success_response('登录成功', { user: user.to_hash })
      else
        flash[:success] = '登录成功'
        redirect '/'
      end
    else
      if request.accept.include?('application/json')
        json_response({ success: false, message: '用户名或密码错误' }, 401)
      else
        flash[:error] = '用户名或密码错误'
        redirect '/login'
      end
    end
  end

  # 注销
  get '/logout' do
    session.clear
    flash[:info] = '已安全退出'
    redirect '/login'
  end

  # === API 路由 ===
  
  # API 版本信息
  get '/api/version' do
    json_response({
      version: '2.0.0',
      name: 'CICD API',
      description: '持续集成部署系统API',
      timestamp: Time.now.to_i
    })
  end

  # API 健康检查
  get '/api/health' do
    db_status = begin
      DB.test_connection
      'healthy'
    rescue
      'unhealthy'
    end

    json_response({
      status: 'ok',
      database: db_status,
      uptime: Time.now.to_i - STARTUP_TIME,
      timestamp: Time.now.to_i
    })
  end

  # 用户信息 API
  get '/api/user' do
    login_required
    success_response('获取用户信息成功', current_user.to_hash)
  end

  # 项目列表 API
  get '/api/projects' do
    login_required
    projects = if current_user.admin?
      Project.all
    else
      Project.where(user_id: current_user.id).all
    end
    
    success_response('获取项目列表成功', projects.map(&:to_hash))
  end

  # === 错误处理 ===
  
  not_found do
    if request.accept.include?('application/json')
      json_response({ success: false, message: '页面不存在' }, 404)
    else
      erb :not_found
    end
  end

  error do
    error = env['sinatra.error']
    
    puts "应用程序错误: #{error.message}"
    puts error.backtrace.first(5).join('\n')

    if request.accept.include?('application/json')
      json_response({ success: false, message: '服务器内部错误' }, 500)
    else
      erb :error
    end
  end

  # 应用程序启动后的初始化
  configure do
    puts "CICD系统已启动 - 端口: #{CONFIG['app_port']}"
    puts "访问地址: http://localhost:#{CONFIG['app_port']}"
    puts "管理员账户: admin / admin123"
  end
end

# 运行应用程序
if __FILE__ == $0
  CicdApp.run!
end
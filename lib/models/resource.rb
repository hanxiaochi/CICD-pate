# 资源模型
class Resource < Sequel::Model(:resources)
  plugin :timestamps, update_on_create: true
  plugin :validation_helpers
  one_to_many :services

  def validate
    super
    validates_presence :name
    # 验证主机地址（IP或域名）
    if host
      # 检查是否为有效的IP地址或域名
      unless host.match?(/\A\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\z/) || host.match?(/\A[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*\z/)
        errors.add(:host, '主机地址格式不正确')
      end
    else
      errors.add(:host, '主机地址不能为空')
    end
    
    # 验证认证信息
    if type == 'SSH'
      validates_presence :username
      # SSH需要密码或密钥中的至少一个
      if (password.nil? || password.empty?) && (ssh_key_path.nil? || ssh_key_path.empty?)
        errors.add(:authentication, 'SSH资源需要提供密码或密钥路径')
      end
    elsif type == 'Windows'
      validates_presence [:username, :password]
    end
  end

  def online?
    status == 'online'
  end

  def check_connectivity
    begin
      require 'timeout'
      require 'socket'
      
      port_to_check = port || (type == 'SSH' ? 22 : (type == 'Windows' ? 5985 : (type == 'Docker' ? 2376 : 80)))
      
      Timeout::timeout(5) do
        TCPSocket.new(host, port_to_check).close
      end
      
      update(status: 'online', last_check: Time.now)
      true
    rescue => e
      update(status: 'offline', last_check: Time.now)
      false
    end
  end

  def ssh_connect(&block)
    return nil unless type == 'SSH'
    
    options = {
      port: port || 22,
      timeout: 10
    }

    if ssh_key_path && !ssh_key_path.empty? && File.exist?(ssh_key_path)
      options[:keys] = [ssh_key_path]
      options[:auth_methods] = ["publickey"]
    elsif password && !password.empty?
      options[:password] = password
      options[:auth_methods] = ["password"]
    else
      raise "没有提供有效的认证信息"
    end

    begin
      require 'net/ssh'
      Net::SSH.start(host, username, options) do |ssh|
        yield ssh if block_given?
      end
    rescue Net::SSH::AuthenticationFailed => e
      raise "SSH认证失败: #{e.message}"
    rescue Net::SSH::ConnectionFailed => e
      raise "SSH连接失败: #{e.message}"
    rescue => e
      raise "SSH连接错误: #{e.message}"
    end
  end

  def execute_command(command)
    result = { success: false, output: '', error: '' }
    
    begin
      if type == 'SSH'
        ssh_connect do |ssh|
          output = ssh.exec!(command)
          result[:success] = true
          result[:output] = output
        end
      else
        result[:error] = "不支持的资源类型: #{type}"
      end
    rescue => e
      result[:error] = e.message
    end
    
    result
  end
end
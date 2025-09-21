# Git插件
class GitPlugin
  def self.clone_repository(repo_url, target_path, options = {})
    begin
      branch = options[:branch] || 'main'
      depth = options[:depth] || 1
      
      cmd = "git clone"
      cmd += " --depth #{depth}" if depth > 0
      cmd += " --branch #{branch}" if branch
      cmd += " #{repo_url} #{target_path}"
      
      result = system(cmd)
      
      if result
        { success: true, message: '仓库克隆成功' }
      else
        { success: false, message: '仓库克隆失败' }
      end
    rescue => e
      { success: false, message: "Git操作失败: #{e.message}" }
    end
  end

  def self.pull_latest(repo_path, branch = 'main')
    begin
      Dir.chdir(repo_path) do
        system("git checkout #{branch}")
        result = system("git pull origin #{branch}")
        
        if result
          { success: true, message: '代码拉取成功' }
        else
          { success: false, message: '代码拉取失败' }
        end
      end
    rescue => e
      { success: false, message: "Git拉取失败: #{e.message}" }
    end
  end

  def self.get_commit_info(repo_path)
    begin
      Dir.chdir(repo_path) do
        hash = `git rev-parse HEAD`.strip
        message = `git log -1 --pretty=%B`.strip
        author = `git log -1 --pretty=%an`.strip
        date = `git log -1 --pretty=%ad`.strip
        
        {
          success: true,
          commit_hash: hash,
          commit_message: message,
          author: author,
          date: date
        }
      end
    rescue => e
      { success: false, message: "获取提交信息失败: #{e.message}" }
    end
  end

  def self.get_changed_files(repo_path, from_commit = nil, to_commit = 'HEAD')
    begin
      Dir.chdir(repo_path) do
        if from_commit
          files = `git diff --name-only #{from_commit}..#{to_commit}`.split("\n")
        else
          files = `git diff --name-only HEAD~1..HEAD`.split("\n")
        end
        
        { success: true, files: files }
      end
    rescue => e
      { success: false, message: "获取变更文件失败: #{e.message}" }
    end
  end
end
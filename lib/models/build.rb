# 构建模型
class Build < Sequel::Model
  many_to_one :project
  many_to_one :user
  
  def to_hash
    {
      id: id,
      project_id: project_id,
      user_id: user_id,
      status: status,
      build_number: build_number,
      commit_hash: commit_hash,
      branch: branch,
      start_time: start_time,
      end_time: end_time,
      duration: duration,
      log_content: log_content,
      created_at: created_at,
      updated_at: updated_at
    }
  end
  
  def success?
    status == 'success'
  end
  
  def failed?
    status == 'failed'
  end
  
  def running?
    status == 'running'
  end
end
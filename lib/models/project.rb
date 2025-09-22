# 项目模型
class Project < Sequel::Model(:projects)
  plugin :timestamps, update_on_create: true
  plugin :validation_helpers
  many_to_one :user
  many_to_one :workspace
  one_to_many :builds
  one_to_many :deployments
  
  # 明确定义允许的字段
  set_allowed_columns :name, :repo_url, :branch, :repo_type, :project_type, :environment_vars, :user_id, :workspace_id, :description

  def validate
    super
    validates_presence :name
    # 允许repo_url为空
    validates_unique :name
    if repo_type
      validates_includes ['git', 'svn'], :repo_type
    end
    if project_type
      validates_includes ['java', 'nodejs', 'python', 'go', 'php', 'docker'], :project_type
    end
  end

  def latest_build
    builds_dataset.order(Sequel.desc(:created_at)).first
  end

  def latest_deployment
    deployments_dataset.order(Sequel.desc(:created_at)).first
  end

  def is_running?
    latest_deployment&.status == 'success'
  end

  def build_count
    builds_dataset.count
  end

  def success_rate
    total = builds_dataset.count
    return 0 if total == 0
    
    success = builds_dataset.where(status: 'success').count
    (success.to_f / total * 100).round(2)
  end

  def get_environment_variables
    return {} if environment_vars.nil? || environment_vars.empty?
    
    begin
      JSON.parse(environment_vars)
    rescue JSON::ParserError
      {}
    end
  end

  def set_environment_variables(vars_hash)
    self.environment_vars = vars_hash.to_json
  end

  def before_create
    super
    self.created_at = Time.now
    self.updated_at = Time.now
  end

  def before_update
    super
    self.updated_at = Time.now
  end

  def to_hash
    super.merge(
      latest_build: latest_build&.to_hash,
      latest_deployment: latest_deployment&.to_hash,
      build_count: build_count,
      success_rate: success_rate,
      is_running: is_running?
    )
  end
end
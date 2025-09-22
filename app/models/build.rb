class Build < ApplicationRecord
  belongs_to :project
  has_many :artifacts, dependent: :destroy

  validates :project_id, presence: true
  validates :commit, presence: true

  after_create :generate_sbom

  private

  def generate_sbom
    # 模拟 SBOM 生成逻辑（可调用外部工具或解析依赖）
    sbom_data = {
      "project" => project.name,
      "commit" => commit,
      "dependencies" => [
        { "name" => "rails", "version" => "7.0.4" },
        { "name" => "bootstrap", "version" => "5.3.0" }
      ],
      "checksum" => Digest::SHA256.hexdigest(commit),
      "generated_at" => Time.now
    }

    artifacts.create(content: sbom_data.to_json, type: "sbom")
  end
end
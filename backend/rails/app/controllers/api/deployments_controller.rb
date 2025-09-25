# frozen_string_literal: true
module Api
  class DeploymentsController < BaseController
    def create
      steps = [
        { key: "validate", label: "校验参数", ok: true },
        { key: "connect", label: "连接目标服务器", ok: true },
        { key: "upload", label: "上传成品包", ok: true },
        { key: "deploy", label: "部署项目", ok: true },
        { key: "verify", label: "部署验证", ok: true }
      ]
      render json: { ok: true, steps:, deploymentId: 1001 }
    end

    def history
      render json: {
        ok: true,
        items: [
          { id: 1001, project_id: 1, package_id: 11, target_id: 1, status: "success", finished_at: Time.now },
          { id: 1000, project_id: 3, package_id: 21, target_id: 2, status: "failed", finished_at: Time.now - 7200 }
        ]
      }
    end

    def rollback
      render json: { ok: true, id: params[:id].to_i }
    end
  end
end
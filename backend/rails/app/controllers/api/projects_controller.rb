# frozen_string_literal: true
module Api
  class ProjectsController < BaseController
    def index
      # demo data; system_id references Systems
      render json: [
        { id: 1, system_id: 1, name: "mall-api" },
        { id: 2, system_id: 1, name: "mall-admin" },
        { id: 3, system_id: 2, name: "cms-web" }
      ]
    end

    def packages
      pid = params[:id].to_i
      render json: [
        { id: 11, project_id: pid, name: "mall-api-1.0.0.jar" },
        { id: 12, project_id: pid, name: "mall-api-1.0.1.jar" }
      ]
    end
  end
end
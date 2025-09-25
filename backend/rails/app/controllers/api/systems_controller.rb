# frozen_string_literal: true
module Api
  class SystemsController < BaseController
    def index
      render json: [
        { id: 1, name: "电商系统" },
        { id: 2, name: "内容中心" }
      ]
    end
  end
end
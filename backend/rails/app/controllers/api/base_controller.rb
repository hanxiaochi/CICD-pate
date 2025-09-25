# frozen_string_literal: true
module Api
  class BaseController < ApplicationController
    def login
      # Minimal placeholder: always returns a fake token
      render json: { token: "demo-token", ok: true }
    end

    private

    def paginate(collection)
      page = params.fetch(:page, 1).to_i
      page_size = params.fetch(:pageSize, 10).to_i
      items = collection
      total = items.size
      offset = (page - 1) * page_size
      items = items.slice(offset, page_size) || []
      { items:, total:, page:, pageSize: page_size }
    end
  end
end
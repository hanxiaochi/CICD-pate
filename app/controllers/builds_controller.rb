class BuildsController < ApplicationController
  before_action :authenticate_user!

  def index
    @builds = Build.all.order(created_at: :desc)
    render 'index'
  end

  def create
    @build = Build.new(build_params)
    if @build.save
      render json: { success: true, data: @build }, status: :created
    else
      render json: { success: false, errors: @build.errors }, status: :unprocessable_entity
    end
  end

  private

  def build_params
    params.require(:build).permit(:project_id, :branch, :commit, :env)
  end
end
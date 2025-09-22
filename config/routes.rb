Rails.application.routes.draw do
  # 页面路由（前端展示）
  get '/builds', to: 'builds#index'
  get '/projects', to: 'projects#index'
  get '/assets', to: 'assets#index'
  get '/users', to: 'users#index'
  get '/system', to: 'system#index'

  # API 路由（仅供前后端交互）
  namespace :api do
    resources :builds, only: [:index, :create, :show]
    resources :projects, only: [:index, :create, :update]
    resources :assets, only: [:index]
    resources :users, only: [:index, :create]
  end

  # 默认首页
  root 'builds#index'
end
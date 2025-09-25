# frozen_string_literal: true
Rails.application.routes.draw do
  scope :api, defaults: { format: :json } do
    # Auth (placeholder)
    post "login", to: "api/base#login"

    # Systems / Projects / Packages (placeholders)
    get  "systems", to: "api/systems#index"
    get  "projects", to: "api/projects#index"
    get  "projects/:id/packages", to: "api/projects#packages"

    # Targets
    get    "targets",          to: "api/targets#index"
    post   "targets",          to: "api/targets#create"
    put    "targets/:id",      to: "api/targets#update"
    delete "targets/:id",      to: "api/targets#destroy"
    post   "targets/test-ssh", to: "api/targets#test_ssh"
    post   "targets/test-connection", to: "api/targets#test_connection"
    get    "targets/:id/fs",  to: "api/targets#fs"
    get    "targets/:id/processes", to: "api/targets#processes"

    # Deployments
    post "deployments", to: "api/deployments#create"
    get  "deployments/history", to: "api/deployments#history"
    post "deployments/:id/rollback", to: "api/deployments#rollback"
  end

  get "/up", to: proc { [200, {"Content-Type"=>"application/json"}, [{ ok: true }.to_json]] }
end
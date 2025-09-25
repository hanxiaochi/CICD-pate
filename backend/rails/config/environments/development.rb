# frozen_string_literal: true
require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Code reloading and debugging for development
  config.enable_reloading = true
  config.consider_all_requests_local = true
  config.server_timing = true

  config.eager_load = false
  config.log_level = :debug

  # Allow all hosts for local/dev usage
  config.hosts.clear
end
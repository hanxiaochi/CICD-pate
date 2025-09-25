# frozen_string_literal: true
require "active_support/core_ext/integer/time"

Rails.application.configure do
  config.eager_load = true
  config.consider_all_requests_local = false
  config.log_level = :info

  # In production you typically have a reverse proxy serving static files
  # Keep minimal settings for API-only app
end
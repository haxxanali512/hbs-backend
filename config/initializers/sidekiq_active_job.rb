begin
  require "sidekiq/active_job"
rescue LoadError
  # Sidekiq may not be available in some environments (e.g., tests without the gem)
end

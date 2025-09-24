Sidekiq.configure_server do |config|
  config.redis = {
    url: "redis://hbs_data_processing-redis:6379/0",
    size: 5
  }
end

Sidekiq.configure_client do |config|
  config.redis = {
    url: "redis://hbs_data_processing-redis:6379/0",
    size: 5
  }
end

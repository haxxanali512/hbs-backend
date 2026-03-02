class HealthController < ApplicationController
  def show
    checks = {
      database: database_healthy?,
      redis: redis_healthy?,
      sidekiq: sidekiq_healthy?
    }

    all_healthy = checks.values.all?

    payload = {
      status: all_healthy ? "ok" : "error",
      checks: checks,
      timestamp: Time.current.iso8601
    }
    # Opt-in env check: GET /up?env=1 to confirm RAILS_ENV and Active Storage service (useful for Capistrano/staging debugging)
    if params[:env].present?
      payload[:rails_env] = Rails.env
      payload[:active_storage_service] = Rails.application.config.active_storage.service.to_s
    end

    render json: payload, status: all_healthy ? :ok : :service_unavailable
  end

  private

  def database_healthy?
    ActiveRecord::Base.connection.execute("SELECT 1")
    true
  rescue
    false
  end

  def redis_healthy?
    Redis.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0")).ping == "PONG"
  rescue
    false
  end

  def sidekiq_healthy?
    Sidekiq.redis { |conn| conn.ping == "PONG" }
  rescue
    false
  end
end

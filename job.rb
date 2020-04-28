require 'sidekiq'
require 'sidekiq/api'
require 'sidekiq-status'
require_relative 'email'

Sidekiq.configure_server do |config|
  host = ENV.fetch('REDIS_PORT_6379_TCP_ADDR', 'localhost')
  port = ENV.fetch('REDIS_PORT_6379_TCP_PORT', 6379)
  config.redis = { url: "redis://#{host}:#{port}" }

  Sidekiq::Status.configure_server_middleware config, expiration: 432000 # 5 days
  Sidekiq::Status.configure_client_middleware config, expiration: 432000 # 5 days
end

Sidekiq.configure_client do |config|
  host = ENV.fetch('REDIS_PORT_6379_TCP_ADDR', 'localhost')
  port = ENV.fetch('REDIS_PORT_6379_TCP_PORT', 6379)
  config.redis = { url: "redis://#{host}:#{port}" }

  Sidekiq::Status.configure_client_middleware config, expiration: 432000 # 5 days
end

class CchecksEmail
  include Sidekiq::Worker
  include Sidekiq::Status::Worker

  def perform(to, pkg, status, flavor, time, regex, check_date_time)
    email = email_prepare(to: to, pkg: pkg, status: status,
      flavor: flavor, time: time, regex: regex,
      check_date_time: check_date_time)
    email_send(email)
  end
end

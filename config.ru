require_relative 'api'
require 'sidekiq'
require 'sidekiq/web'
require 'sidekiq-status/web'
require 'sidekiq-status'

Sidekiq.configure_client do |config|
  host = ENV.fetch('REDIS_PORT_6379_TCP_ADDR', 'localhost')
  port = ENV.fetch('REDIS_PORT_6379_TCP_PORT', 6379)
  config.redis = { url: "redis://#{host}:#{port}" }

  Sidekiq::Status.configure_client_middleware config, expiration: 432000 # 5 days
end

run Rack::URLMap.new('/' => CCAPI, '/sidekiq' => Sidekiq::Web)

# map '/' do
#   run CCAPI
# end

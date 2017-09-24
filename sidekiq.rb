require 'sidekiq'
require 'clockwork'
# require 'redis'

require_relative "scrape"

# $redis = Redis.new

# class HardWorker
#   include Sidekiq::Worker

#   def perform(msg = "lulz you forgot a msg!")
#     $redis.lpush("sinkiq-example-messages", msg)
#   end
# end

class CranChecksWorker
	include Sidekiq::Worker

	def perform
		scrape_all()
	end
end

CranChecksWorker.perform_in(2.minutes)

# frozen_string_literal: true

require "connection_pool"

require_relative "slow_ride/version"

module SlowRide
  Error = Class.new(StandardError)
  RedisNotConfigured = Class.new(Error)

  class << self
    def enable_redis(max_connections: 25, &block)
      @redis_pool = ConnectionPool.new(size: max_connections, &block)
    end

    def redis(&block)
      if @redis_pool
        @redis_pool.with(&block)
      else
        raise RedisNotConfigured, "Must configure Redis with `SlowRide.enable_redis { Redis.new(...) }`"
      end
    end
  end

  class Adapter
    def initialize(failure_threshold:, minimum_checks: 1_000, &failure_handler)
      @failure_threshold = failure_threshold
      @minimum_checks = minimum_checks
      @failure_handler = failure_handler
    end

    def check
      checked_count = checked

      begin
        yield
      rescue => ex
        failed_count = failed

        if checked_count >= @minimum_checks && failed_count.to_f / checked_count >= @failure_threshold
          @failure_handler.call failed_count, checked_count
          failure_threshold_exceeded failed: failed_count, checked: checked_count
        end
        raise ex
      end
    end

    def failure_threshold_exceeded(failed:, checked:)
    end
  end

  class Redis < Adapter
    # The default expiration for a given key. We set it to a week and refresh
    # the expiration each time a check is made.
    #
    # IT'S BEEN ...
    ONE_WEEK = 60 * # seconds
               60 * # minutes
               24 * # hours
               7    # days

    def initialize(name, failure_threshold:, minimum_checks: 1_000, max_duration: ONE_WEEK, &failure_handler)
      super failure_threshold: failure_threshold, minimum_checks: minimum_checks,  &failure_handler
      @name = name
      @max_duration = max_duration
      @checked_key = "slow-ride:#{name}:checked"
      @failed_key = "slow-ride:#{name}:failed"
    end

    def checked
      SlowRide.redis do |redis|
        redis.pipelined do |redis|
          redis.incr @checked_key
          redis.expire @checked_key, @max_duration
          redis.expire @failed_key, @max_duration
        end
      end.first
    end

    def failed
      SlowRide.redis { |redis| redis.incr @failed_key }
    end

    def failure_threshold_exceeded(failed:, checked:)
      SlowRide.redis do |redis|
        redis.pipelined do |redis|
          redis.del @checked_key
          redis.del @failed_key
        end
      end
    end
  end
end

require 'redis'
require "#{File.dirname(__FILE__)}/redis_multi_list/list"

module RedisMultiList
  def self.redis=(redis)
    raise InvalidRedisInstanceError unless redis.is_a?(Redis)
    @@redis = redis
  end

  def self.redis
    @@redis
  end

  def self.get(key = nil)
    raise NoRedisConnectionError if !defined?(@@redis) || @@redis.nil?
    RedisMultiList::List.new(key)
  end

  def self.namespace=(namespace)
    @@namespace = namespace
  end

  def self.namespace
    (defined?(@@namespace) && !@@namespace.nil?) ? @@namespace : "redismultilist"
  end
end

class NoRedisConnectionError < StandardError; end
class InvalidRedisInstanceError < StandardError; end
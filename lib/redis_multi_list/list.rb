require 'securerandom'

module RedisMultiList
  class List
    include Enumerable
    attr_reader :key

    def initialize(key = nil)
      @key = key.nil? ? generated_key : key
    end

    # -- Selection / Iteration
    def each
      redis.lrange(namespaced_key, 0, redis.llen(namespaced_key)).each do |value|
        if sublist?(value)
          yield List.new(remove_namespace(value))
        else
          yield value
        end
      end
    end

    def [](index)
      value = redis.lindex(namespaced_key, index)
      return nil if value.nil?
      sublist?(value) ? List.new(remove_namespace(value)) : value
    end

    def all
      array = redis.lrange(namespaced_key, 0, redis.llen(namespaced_key))
      array.each_with_index do |value, i|
        array[i] = List.new(remove_namespace(value)) if sublist?(value)
      end

      array
    end

    def count
      redis.llen(namespaced_key)
    end

    # -- Comparison
    # In the case where comp is another List object we just compare the key
    # We don't want to be comparing redis values because the results will be the same
    # if the keys match
    def ==(comp)
      comp.is_a?(List) ? @key == comp.key : to_a == comp
    end

    # -- Conversion
    # This returns a raw, deep array
    def to_a
      array = all
      array.each_with_index do |value, i|
        array[i] = value.to_a if value.is_a?(List)
      end
    end

    # -- Modification
    def []=(index, value)
      value = storable_value(value)

      if index > 0 && !redis.exists(namespaced_key)
        index.times { redis.rpush(namespaced_key, "") }
      end

      llen = redis.llen(namespaced_key)

      if index < llen
        redis.lset(namespaced_key, index, value)
      else
        (index - llen).times { redis.rpush(namespaced_key, "") }
        redis.rpush(namespaced_key, value)
      end
    end

    def <<(value)
      push(value)
    end

    def +(value)
      if value.is_a?(Array)
        value.each do |item|
          push(item)
        end
      else
        push(value)
      end
    end

    def push(value)
      redis.rpush(namespaced_key, storable_value(value))
    end

    def pop
      redis.ltrim(namespaced_key, 0, -2)
    end

    # Redis doesn't support delete at index, so we're copying the values in redis, keeping all but the index we're
    # removing, deleting the list, and reloading it. Due to the complexity of this call it is recommended that you
    # do not use it.
    def delete_at(index)
      len = count
      values = redis.lrange(namespaced_key, 0, len-1)
      redis.multi do
        new_values = []

        values.each_with_index do |value, i|
          new_values << value unless i == index
        end

        redis.del(namespaced_key)
        new_values.each do |value|
          redis.rpush(namespaced_key, value)
        end
      end
    end

    def delete(value)
      value = value.is_a?(List) ? sublist_value(value) : value
      redis.lrem(namespaced_key, 0, value)
    end

    def clear
      redis.del(namespaced_key)
    end

    # -- Storage helpers
    def self.namespaced_key_for(key)
      "#{RedisMultiList.namespace}:#{key}"
    end

    def namespaced_key
      List.namespaced_key_for(@key)
    end

    protected

    def redis
      RedisMultiList.redis
    end

    def remove_namespace(key)
      @@_remove_namespace_regex ||= Regexp.new("#{RedisMultiList.namespace}:(~>)?(.+)")
      key.match(@@_remove_namespace_regex)[2]
    end

    def storable_value(value)
      raise ArgumentError, "The value  #{value} does not represent a list, is not a string, and cannot be made a string" unless value_storable?(value)
      determine_stored_value(value)
    end

    def value_storable?(value)
      return true if value.is_a?(List) || value.is_a?(Array)
      return true if value.respond_to? :to_s
      false
    end

    def determine_stored_value(value)
      if value.is_a?(List)
        sublist_value(value)
      elsif value.is_a?(Array)
        list = List.new
        value.each do |subvalue|
          list << subvalue
        end

        sublist_value(list)
      else
        value.to_s
      end
    end

    def generated_key
      SecureRandom.hex
    end

    def sublist?(value)
      @@_sublist_matcher = Regexp.new("^#{RedisMultiList.namespace}:~>")
      value.match(@@_sublist_matcher)
    end

    def sublist_value(list)
      "#{RedisMultiList.namespace}:~>#{list.key}"
    end
  end
end
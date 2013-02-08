require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe RedisArray do
  after :each do
    if defined?(Redis::Connection::Memory) # fake redis
      Redis::Connection::Memory.reset_all_databases
    else # Sometimes we test against a live redis connection.
      RedisArray.redis.del(RedisArray.redis.keys("#{RedisArray.namespace}:*"))
    end
  end

  context "defining redis" do
    before(:each) do
      RedisArray.class_variable_set :@@redis, nil
    end

    it "provides an interface to set the redis instance" do
      RedisArray.respond_to?(:redis=).should be_true
    end

    it "raises a InvalidRedisInstanceError if we attempt to set redis to a non-redis instance" do
      expect { RedisArray.redis = Array.new }.to raise_exception InvalidRedisInstanceError
    end

    it "can return the redis instance" do
      redis = Redis.new
      RedisArray.redis = redis
      RedisArray.redis.should == redis
    end
  end

  context "getting lists" do
    before(:each) do
      RedisArray.class_variable_set :@@redis, nil
    end

    it "raises a NoRedisConnectionError if we attempt to use get without a redis connection" do
      expect { RedisArray.get("some key") }.to raise_exception NoRedisConnectionError
    end

    it "returns a RedisArray object representing the key" do
      RedisArray.redis = Redis.new
      list = RedisArray.get("test")
      list.should be_an_instance_of RedisArray
      list.key.should == "test"
    end
  end

  context "namespacing" do
    before(:each) do
      RedisArray.class_variable_set :@@namespace, nil
    end

    it "can set a custom namespace" do
      RedisArray.namespace = "rml"
      RedisArray.namespace.should == "rml"
    end

    it "sets a default key namespace to RedisArray" do
      RedisArray.namespace.should == "redisarray"
    end
  end

  context "list usage" do
    before(:each) do
      RedisArray.redis = Redis.new
    end

    context "element access" do
      it "can access a random item within the list" do
        k = namespaced_key("test")
        RedisArray.redis.rpush(k, "test-value")
        RedisArray.redis.rpush(k, "test-value2")
        list = RedisArray.new("test")
        list[0].should == "test-value"
        list[1].should == "test-value2"
      end

      it "returns nil if the index does not exist within the list" do
        k = namespaced_key("test")
        RedisArray.redis.rpush(k, "test-value")
        RedisArray.redis.rpush(k, "test-value2")
        list = RedisArray.new("test")
        list[2].should be_nil
      end

      it "can set a random item within the list that has already been set" do
        k = namespaced_key("test")
        RedisArray.redis.rpush(k, "test-value")
        list = RedisArray.new("test")
        list[0] = "test-value2"
        RedisArray.redis.lindex(k, 0).should == "test-value2"
      end

      it "can set a random item within the list that has not been set" do
        k = namespaced_key("test")
        list = RedisArray.new("test")
        list[0] = "test-value0"
        list[4] = "test-value4"
        RedisArray.redis.lrange(k, 0, 5).should == ["test-value0", "", "", "", "test-value4"]
      end

      it "can append an item to the list" do
        k = namespaced_key("test")
        list = RedisArray.new("test")
        list << "test-value0"
        RedisArray.redis.lindex(k, 0).should == "test-value0"
      end

      it "can set a sub list within a list that has been set" do
        k = namespaced_key("test")
        RedisArray.redis.rpush(k, "test-value")
        list = RedisArray.new("test")
        sublist = RedisArray.new("test2")
        list[0] = sublist
        RedisArray.redis.lindex(k, 0).should == "redisarray:~>test2"
      end

      it "returns a List object when accessing subscript and the value points to a list" do
        k = namespaced_key("test")
        RedisArray.redis.rpush(k, "redisarray:~>test2")
        list = RedisArray.new("test")
        sublist = RedisArray.new("test2")
        list[0].should == sublist
      end

      it "can set a sub list within a list that has not been set" do
        k = namespaced_key("test")
        list = RedisArray.new("test")
        list[0] = RedisArray.new("test2")
        RedisArray.redis.lindex(k, 0).should == "redisarray:~>test2"
      end

      it "can append a sub list within a list" do
        k = namespaced_key("test")
        list = RedisArray.new("test")
        sublist = RedisArray.new("test2")
        list << sublist
        RedisArray.redis.lindex(k, 0).should == "redisarray:~>test2"
      end

      it "can store a sub list without a name" do
        k = namespaced_key("test")
        list = RedisArray.new("test")
        sublist = RedisArray.new
        list << sublist
        RedisArray.redis.lindex(k, 0).should == "redisarray:~>#{sublist.key}"
      end

      it "can store a list without a name" do
        list = RedisArray.new
        list << "test-value"
        RedisArray.redis.lindex("redisarray:#{list.key}", 0).should == "test-value"
      end

      it "can store a regular array as a sub list" do
        k = namespaced_key("test")
        list = RedisArray.new("test")
        sublist = %w(test test2 test3)
        list << sublist
        k2 = "redisarray:#{list[0].key}"
        RedisArray.redis.lindex(k, 0).should == "redisarray:~>#{list[0].key}"
        RedisArray.redis.lrange("redisarray:#{list[0].key}", 0, 2).should == sublist
      end

      it "can loop through the elements in the list" do
        k = namespaced_key("test")
        RedisArray.redis.rpush(k, "test-value")
        RedisArray.redis.rpush(k, "test-value2")
        RedisArray.redis.rpush(k, "test-value3")
        list = RedisArray.new("test")
        list.each_with_index do |item, i|
          case i
            when 0 then item.should == "test-value"
            when 1 then item.should == "test-value2"
            when 2 then item.should == "test-value3"
          end
        end
      end

      it "can concatenate an array of items/lists" do
        list = RedisArray.new("test")
        sublist = RedisArray.new("subtest")
        sublist << "subtest1"
        sublist << "subtest2"
        list += ["test1", "test2", sublist]
        list.should == ["test1", "test2", ["subtest1", "subtest2"]]
      end

    end

    it "can be converted into a plain array" do
      list = RedisArray.new("test")

      sublist1 = RedisArray.new("sublist1")
      sublist1 << "subtest1-1"
      sublist1 << "subtest1-2"

      sublist2 = RedisArray.new("sublist2")
      sublist2 << "subtest2-1"
      sublist2 << "subtest2-2"

      list << "test1"
      list << "test2"
      list << sublist1
      list << "test3"
      list << sublist2

      list.to_a.should == ["test1", "test2", ["subtest1-1", "subtest1-2"], "test3", ["subtest2-1", "subtest2-2"]]
    end

    it "can determine the number of elements in the list" do
      list = RedisArray.new("test")
      list << "test1"
      list << "test2"
      list << "test3"
      list.count.should == 3
    end

    it "can determine if there are any elements in the list" do
      list = RedisArray.new("test")
      list.any?.should_not be_true
      list << "test1"
      list.any?.should be_true
    end

    it "can remove an item from the list by index" do
      k = namespaced_key("test")
      RedisArray.redis.rpush(k, "test-value")
      RedisArray.redis.rpush(k, "test-value2")
      RedisArray.redis.rpush(k, "test-value3")
      list = RedisArray.new("test")
      list.delete_at(1)
      RedisArray.redis.lrange(k, 0, 3).should == %w(test-value test-value3)
    end

    it "can pop the last element from a list" do
      k = namespaced_key("test")
      RedisArray.redis.rpush(k, "test-value")
      RedisArray.redis.rpush(k, "test-value2")
      RedisArray.redis.rpush(k, "test-value3")
      list = RedisArray.new("test")
      list.pop
      RedisArray.redis.lrange(k, 0, 3).should == %w(test-value test-value2)
    end

    it "can remove all items from a list" do
      k = namespaced_key("test")
      RedisArray.redis.rpush(k, "test-value")
      RedisArray.redis.rpush(k, "test-value2")
      RedisArray.redis.rpush(k, "test-value3")
      list = RedisArray.new("test")
      list.clear
      RedisArray.redis.exists(k).should_not be_true
    end


    it "can remove all items from a list as well as all sublists" do
      pending "the addition of deep removals"
    end

    it "can remove an item matching a value from a list" do
      k = namespaced_key("test")
      RedisArray.redis.rpush(k, "test-value")
      RedisArray.redis.rpush(k, "test-value2")
      RedisArray.redis.rpush(k, "test-value3")
      list = RedisArray.new("test")
      list.delete("test-value")
      RedisArray.redis.lrange(k, 0, 2).should == %w(test-value2 test-value3)
    end

    it "can remove a sublist from a list" do
      k = namespaced_key("test")
      RedisArray.redis.rpush(k, "test-value")
      RedisArray.redis.rpush(k, "redisarray:~>test2")
      RedisArray.redis.rpush(k, "test-value3")
      list = RedisArray.new("test")
      list2 = RedisArray.new("test2")
      list.delete(list2)
      RedisArray.redis.lrange(k, 0, 2).should == %w(test-value test-value3)
    end

    it "does not remove elements of a sublist when the sublist is removed from a parent list" do
      k = namespaced_key("test")
      k2 = "RedisArray:~>test2"
      RedisArray.redis.rpush(k, k2)
      RedisArray.redis.rpush(k2, "test-value")
      RedisArray.redis.rpush(k2, "test-value2")

      list = RedisArray.new("test")
      list2 = RedisArray.new("test2")

      list.delete(list2)
      RedisArray.redis.lrange(k2, 0, 2).should == %w(test-value test-value2)
    end

    it "can remove a sublist from a list as well as all sublists" do
      pending "the addition of deep removals"
    end
  end


  def namespaced_key(key)
    "#{RedisArray.namespace}:#{key}"
  end
end

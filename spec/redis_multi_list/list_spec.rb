require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe RedisMultiList::List do

  before :all do
    RedisMultiList.redis = Redis.new
  end

  after :each do
    if defined?(Redis::Connection::Memory) # fake redis
      Redis::Connection::Memory.reset_all_databases
    else # Sometimes we test against a live redis connection.
      RedisMultiList.redis.del(RedisMultiList.redis.keys("#{RedisMultiList.namespace}:*"))
    end
    RedisMultiList::List.class_variable_set :@@pool, nil
  end

  context "element access" do
    it "can access a random item within the list" do
      k = namespaced_key("test")
      RedisMultiList.redis.rpush(k, "test-value")
      RedisMultiList.redis.rpush(k, "test-value2")
      list = RedisMultiList::List.new("test")
      list[0].should == "test-value"
      list[1].should == "test-value2"
    end

    it "returns nil if the index does not exist within the list" do
      k = namespaced_key("test")
      RedisMultiList.redis.rpush(k, "test-value")
      RedisMultiList.redis.rpush(k, "test-value2")
      list = RedisMultiList::List.new("test")
      list[2].should be_nil
    end

    it "can set a random item within the list that has already been set" do
      k = namespaced_key("test")
      RedisMultiList.redis.rpush(k, "test-value")
      list = RedisMultiList::List.new("test")
      list[0] = "test-value2"
      RedisMultiList.redis.lindex(k, 0).should == "test-value2"
    end

    it "can set a random item within the list that has not been set" do
      k = namespaced_key("test")
      list = RedisMultiList::List.new("test")
      list[0] = "test-value0"
      list[4] = "test-value4"
      RedisMultiList.redis.lrange(k, 0, 5).should == ["test-value0", "", "", "", "test-value4"]
    end

    it "can append an item to the list" do
      k = namespaced_key("test")
      list = RedisMultiList::List.new("test")
      list << "test-value0"
      RedisMultiList.redis.lindex(k, 0).should == "test-value0"
    end

    it "can set a sub list within a list that has been set" do
      k = namespaced_key("test")
      RedisMultiList.redis.rpush(k, "test-value")
      list = RedisMultiList::List.new("test")
      sublist = RedisMultiList::List.new("test2")
      list[0] = sublist
      RedisMultiList.redis.lindex(k, 0).should == "redismultilist:~>test2"
    end

    it "returns a List object when accessing subscript and the value points to a list" do
      k = namespaced_key("test")
      RedisMultiList.redis.rpush(k, "redismultilist:~>test2")
      list = RedisMultiList::List.new("test")
      sublist = RedisMultiList::List.new("test2")
      list[0].should == sublist
    end

    it "can set a sub list within a list that has not been set" do
      k = namespaced_key("test")
      list = RedisMultiList::List.new("test")
      list[0] = RedisMultiList::List.new("test2")
      RedisMultiList.redis.lindex(k, 0).should == "redismultilist:~>test2"
    end

    it "can append a sub list within a list" do
      k = namespaced_key("test")
      list = RedisMultiList::List.new("test")
      sublist = RedisMultiList::List.new("test2")
      list << sublist
      RedisMultiList.redis.lindex(k, 0).should == "redismultilist:~>test2"
    end

    it "can store a sub list without a name" do
      k = namespaced_key("test")
      list = RedisMultiList::List.new("test")
      sublist = RedisMultiList::List.new
      list << sublist
      RedisMultiList.redis.lindex(k, 0).should == "redismultilist:~>#{sublist.key}"
    end

    it "can store a list without a name" do
      list = RedisMultiList::List.new
      list << "test-value"
      RedisMultiList.redis.lindex("redismultilist:#{list.key}", 0).should == "test-value"
    end

    it "can store a regular array as a sub list" do
      k = namespaced_key("test")
      list = RedisMultiList::List.new("test")
      sublist = %w(test test2 test3)
      list << sublist
      k2 = "redismultilist:#{list[0].key}"
      RedisMultiList.redis.lindex(k, 0).should == "redismultilist:~>#{list[0].key}"
      RedisMultiList.redis.lrange("redismultilist:#{list[0].key}", 0, 2).should == sublist
    end

    it "can loop through the elements in the list" do
      k = namespaced_key("test")
      RedisMultiList.redis.rpush(k, "test-value")
      RedisMultiList.redis.rpush(k, "test-value2")
      RedisMultiList.redis.rpush(k, "test-value3")
      list = RedisMultiList::List.new("test")
      list.each_with_index do |item, i|
        case i
          when 0 then item.should == "test-value"
          when 1 then item.should == "test-value2"
          when 2 then item.should == "test-value3"
        end
      end
    end

    it "can concatenate an array of items/lists" do
      list = RedisMultiList::List.new("test")
      sublist = RedisMultiList::List.new("subtest")
      sublist << "subtest1"
      sublist << "subtest2"
      list += ["test1", "test2", sublist]
      list.should == ["test1", "test2", ["subtest1", "subtest2"]]
    end

  end

  it "can be converted into a plain array" do
    list = RedisMultiList::List.new("test")

    sublist1 = RedisMultiList::List.new("sublist1")
    sublist1 << "subtest1-1"
    sublist1 << "subtest1-2"

    sublist2 = RedisMultiList::List.new("sublist2")
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
    list = RedisMultiList::List.new("test")
    list << "test1"
    list << "test2"
    list << "test3"
    list.count.should == 3
  end

  it "can determine if there are any elements in the list" do
    list = RedisMultiList::List.new("test")
    list.any?.should_not be_true
    list << "test1"
    list.any?.should be_true
  end

  it "can remove an item from the list by index" do
    k = namespaced_key("test")
    RedisMultiList.redis.rpush(k, "test-value")
    RedisMultiList.redis.rpush(k, "test-value2")
    RedisMultiList.redis.rpush(k, "test-value3")
    list = RedisMultiList::List.new("test")
    list.delete_at(1)
    RedisMultiList.redis.lrange(k, 0, 3).should == %w(test-value test-value3)
  end

  it "can pop the last element from a list" do
    k = namespaced_key("test")
    RedisMultiList.redis.rpush(k, "test-value")
    RedisMultiList.redis.rpush(k, "test-value2")
    RedisMultiList.redis.rpush(k, "test-value3")
    list = RedisMultiList::List.new("test")
    list.pop
    RedisMultiList.redis.lrange(k, 0, 3).should == %w(test-value test-value2)
  end

  it "can remove all items from a list" do
    k = namespaced_key("test")
    RedisMultiList.redis.rpush(k, "test-value")
    RedisMultiList.redis.rpush(k, "test-value2")
    RedisMultiList.redis.rpush(k, "test-value3")
    list = RedisMultiList::List.new("test")
    list.clear
    RedisMultiList.redis.exists(k).should_not be_true
  end


  it "can remove all items from a list as well as all sublists" do
    pending "the addition of deep removals"
  end

  it "can remove an item matching a value from a list" do
    k = namespaced_key("test")
    RedisMultiList.redis.rpush(k, "test-value")
    RedisMultiList.redis.rpush(k, "test-value2")
    RedisMultiList.redis.rpush(k, "test-value3")
    list = RedisMultiList::List.new("test")
    list.delete("test-value")
    RedisMultiList.redis.lrange(k, 0, 2).should == %w(test-value2 test-value3)
  end

  it "can remove a sublist from a list" do
    k = namespaced_key("test")
    RedisMultiList.redis.rpush(k, "test-value")
    RedisMultiList.redis.rpush(k, "redismultilist:~>test2")
    RedisMultiList.redis.rpush(k, "test-value3")
    list = RedisMultiList::List.new("test")
    list2 = RedisMultiList::List.new("test2")
    list.delete(list2)
    RedisMultiList.redis.lrange(k, 0, 2).should == %w(test-value test-value3)
  end

  it "does not remove elements of a sublist when the sublist is removed from a parent list" do
    k = namespaced_key("test")
    k2 = "redismultilist:~>test2"
    RedisMultiList.redis.rpush(k, k2)
    RedisMultiList.redis.rpush(k2, "test-value")
    RedisMultiList.redis.rpush(k2, "test-value2")

    list = RedisMultiList::List.new("test")
    list2 = RedisMultiList::List.new("test2")

    list.delete(list2)
    RedisMultiList.redis.lrange(k2, 0, 2).should == %w(test-value test-value2)
  end

  it "can remove a sublist from a list as well as all sublists" do
    pending "the addition of deep removals"
  end

  def namespaced_key(key)
    "#{RedisMultiList.namespace}:#{key}"
  end
end
require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "RedisMultiList" do
  before(:each) do
    RedisMultiList.class_variable_set :@@namespace, nil
    RedisMultiList.class_variable_set :@@redis, nil
  end

  context "defining redis" do
    it "provides an interface to set the redis instance" do
      RedisMultiList.respond_to?(:redis=).should be_true
    end

    it "raises a InvalidRedisInstanceError if we attempt to set redis to a non-redis instance" do
      expect { RedisMultiList.redis = Array.new }.to raise_exception InvalidRedisInstanceError
    end

    it "can return the redis instance" do
      redis = Redis.new
      RedisMultiList.redis = redis
      RedisMultiList.redis.should == redis
    end
  end

  context "getting lists" do
    let(:redis) { Redis.new }

    it "raises a NoRedisConnectionError if we attempt to use get without a redis connection" do
      expect { RedisMultiList.get("some key") }.to raise_exception NoRedisConnectionError
    end

    it "returns a RedisMultiList::List object representing the key" do
      RedisMultiList.redis = redis
      list = RedisMultiList.get("test")
      list.should be_an_instance_of RedisMultiList::List
      list.key.should == "test"
    end
  end

  it "can set a custom namespace" do
    RedisMultiList.namespace = "rml"
    RedisMultiList.namespace.should == "rml"
  end

  it "sets a default key namespace to redismultilist" do
    RedisMultiList.namespace.should == "redismultilist"
  end
end

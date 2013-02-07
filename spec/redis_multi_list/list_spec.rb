require File.expand_path(File.dirname(__FILE__) + '../spec_helper')

describe RedisMultiList::List do
  before :all do
    RedisMultiList.redis = Redis.new
  end


end
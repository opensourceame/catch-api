module Endpoints
  class Reset < Sinatra::Base

    get '/' do
      User.dataset.delete
      Event.dataset.delete

      redis = Redis.new
      redis.flushall

      redis.set('amsterdam:game:state', 'start')
    end
  end
end

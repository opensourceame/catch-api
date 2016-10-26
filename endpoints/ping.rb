require 'redis'

module Endpoints
  class Ping < Sinatra::Base

    enable :logging

    get '/' do
      content_type :json

      begin
        Redis.connect.set('ping', Time.now)
        redis = 'up'
      rescue
        redis = 'down'
      end

      data = {
        'version'   => $config.version,
        'host'      => request.host,
        'time'      => Time.now.to_s,
        'redis'     => redis
      }

      logger.info   "ping"
      logger.debug  "redis: #{redis}"

      [ 200, JSON.pretty_generate(data) ]
    end

    def test_connection

    end

  end
end

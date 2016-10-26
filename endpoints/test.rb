module Endpoints
  class Test < Base

    set :model, User

    get '/' do

      binding.pry

      logger.fatal '$test already has a value' unless $test.nil?

      $test = 'testing'

      binding.pry

    end

    put '/' do
      binding.pry
    end

  end
end

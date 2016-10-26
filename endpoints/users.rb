module Endpoints
  class Users < Base

    set model: User

    get '/me' do
      user = User[session.user_id] || response.fail("not authenticated")
      response.add_data(user)
    end

    get '/' do

      users = User.all

      unless current_user.type == 'criminal'
        users.each do |user|
          next unless user.type == 'criminal'

            hiding_until_turn = redis.get('amsterdam:criminal:hide')

            if hiding_until_turn

              hiding_until_turn = hiding_until_turn.to_i

              if current_user.turn < hiding_until_turn
                user.location = nil
                logger.debug "criminal is hiding for " + (hiding_until_turn - current_user.turn).to_s + ' turns'
              else
                logger.debug "removing hiding status"
                redis.del('amsterdam:criminal:hide')
              end
            else
              user.location = nil unless rand(10) == 0
            end
        end
      end

      response.set_data(users)
    end

  end
end


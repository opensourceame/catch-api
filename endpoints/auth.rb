require 'httparty'

module Endpoints
  class Auth < Base

    set :model, User

    post '/' do

      session.clear

      require_fields [ :facebook_id, :first_name, :last_name, :type ]

      response.fail "already logged in" if session.authenticated

      data = request.data

      user = User.where(facebook_id: request.data['facebook_id']).first

      if user.nil?

        logger.info "creating new user"

        location = API::Locations.locations.values.sample

        data['type']        = 'criminal' if User.count == 0
        data['location']    = location['id']
        data['picture_url'] = '/images/mrx.png' if request.data['type'] == 'criminal'

        user = User.new(data).save

      else
        logger.info "logging in existing user"
      end

      session.user_id         = user.id
      session.authenticated   = true

      response.add_data(user)
    end
  end
end


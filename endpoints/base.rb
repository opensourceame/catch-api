require 'sinatra/base'
require 'date'

module Endpoints
  class Base < Sinatra::Base

    enable :logging

    set :protection,  false
    set :logging, Logger::DEBUG
    set :show_exceptions, false

    error 500 do
      return [ 500, { errors: [ 'internal server error' ]}.to_json ]
    end

    before do

      response.logger = logger

      begin
        session.role    = :guest if session.role.nil?
      rescue
        response.fail("unable to establish session", 500)
      end

      return true unless env['initial_logging_done'].nil?

      content_type 'application/json'

      env[:start_time] = Time.now

      logger.info   "remote ip:   " + request.client_ip
      logger.info   "process:     " + request.request_method + " on " + request.path
      logger.info   "session id:  " + session.id
      # logger.info   "role:        " + session.role.to_s
      logger.info   "user id:     " + session.user_id.to_s      if session.has_key?('user_id')
      logger.info   "retailer id: " + session.retailer_id.to_s  if session.has_key?('retailer_id')

      env['initial_logging_done'] = true

      check_request
      check_security

      response.fail "game over" if game_over?

      set_view

      request.params['limit'] = 10 unless request.params.has_key?('limit') or ! request.get?

      response.headers['Cache-Control']   = 'no-cache, no-store, must-revalidate'
      response.headers['Expires']         = '0'
      response.request                    = request

    end

    after do

      return false unless session.loaded?

      execution_time = (Time.now - env[:start_time]).round(3)

      logger.info "----- processing time: #{execution_time}s -----"
    end

    set(:role) do |role|
      condition do

        if request.env['rack.session']['role'].nil?
          logger.fatal "no role set in session"
          return false
        end

        if ! role.nil? && (request.env['rack.session']['role'].to_sym == role.to_sym)
          return true
        end

        return false
      end
    end

    def authenticated?
      return false unless session.has_key?('role')
      return false if     session.role == :guest

      true
    end

    def redis
      @redis ||= Redis.new
    end

    def check_security
      return true if request.path == '/auth'
      deny_access "unauthenticated" unless session.authenticated
    end

    def get_view(role = nil, path)

      role      = session.role if role.nil?
      views     = YAML.load_file('config/common/views.yaml')
      data      = views[path][role.to_s] rescue {}

      OpenStruct.new(data)
    end

    # set the view
    def set_view(role = nil)

      path      = '/' + request.path.split(/\//)[1]

      eval("$view_#{$$} = get_view(role, path)")

      logger.info "using view for role: #{role}" unless role.nil?

    end

    def add_filter(name, value)

      filter_name = 'filter:' + name.to_s

      if request.params.has_key?(filter_name)
        p = request.params[filter_name]

        request.params[filter_name] = [p] unless p.is_a?(Array)

        request.params[filter_name].push value

        return request.params
      end

      request.params[filter_name] = value
    end

    def deny_access(message = 'access denied', code = 403)

      logger.fatal "denying access: " + message

      response.fail message, code
    end

    def model
      return settings.model
    end

    def require_user(id)
      deny_access if ! session.user_id == id
    end

    def require_role(role)
      deny_access if ! session.role == role
    end

    def create_object_from_data(data, object_class = nil)
      object_class  = model if object_class.nil?
      object_class  = "Sequel::Models::#{object_class}".to_class if object_class.is_a?(String)
      data          = object_class.wash(data)

      object_class.create(data)
    end

    def require_fields(fields)
      data = request.data

      fields = [ fields ] if fields.is_a?(String)

      # when fields is a model, we get the required fields for that model
      if fields.is_a?(Class)
        fields = fields.required_fields
      end

      for field in fields
        response.add_error "invalid or missing field: #{field}" unless data.dig(field)
      end

      response.fail if response.errors?

    end

    def strip_fields(fields)

     fields = [ fields ] unless fields.is_a?(Array)

      data = request.data

      for field in fields
        f = field.to_s
        data.delete(f) if data.has_key?(f)
      end
    end

    def check_request
      deny_access "request must contain some data" if request.put? && request.data.empty?
    end

    def current_user
      @current_user ||= User[session.user_id]
    end

    def current_location
       @current_location ||= API::Locations.get(current_user.location)
    end

    def game_start
      redis.set('amsterdam:game:state', 'start')
    end

    def game_over?
      logger.debug  redis.get('amsterdam:game:state')
      redis.get('amsterdam:game:state') == 'over'
    end

    def game_over!
      redis.set('amsterdam:game:state', 'over')

      logger.fatal "GAME OVER!"


    end

    def check_turn

      if current_user.type == 'criminal'
        User.where(type: 'agent').each do |u|
          if u.turn < current_user.turn
            deny_access "criminal tried to play out of turn"
          end
        end

        return true
      end

      criminal = User.where(type: 'criminal').first

      deny_access "agent tried to play out of turn" unless criminal.turn > current_user.turn

    end

    def update_turn
      current_user.turn += 1
      current_user.save_changes
    end

    get '/:id' do

      logger.info "fetching " + model.short_name + " with id " + params[:id].to_s

      add_filter 'id', params[:id]

      collection = model.fetch_collection_for_request(request)

      response.fail "not found", 404 if collection.count == 0

      obj       = collection.data.first

      response.set_data obj

      response
    end

    get '/' do
      collection = model.fetch_collection_for_request(request)

      binding.pry if collection.nil?

      response.set_collection collection

      response
    end

    #
    # CREATE A NEW OBJECT
    #
    # TODO: implement multi-object creation (2.0?)
    post '/' do
      logger.info "creating new #{model.to_s}"

      require_fields(model.required_fields)

      object = create_object_from_data(request.data)

      response.fail(object.all_error_messages) unless object.valid?

      object.save

      logger.info "saved with id #{object.id}"

      response.status = 201
      response.add_data({ 'result' => 'ok', 'id' => object.id.to_s})

      response
    end

    put '/' do
      deny_access "not implemented yet"
    end

    put '/:id' do
      logger.info "updating #{model.short_name} #{params[:id]}"

      add_filter(:id, params[:id])

      collection = model.fetch_collection_for_request(request)

      response.fail "not found", 404 if collection.count == 0

      strip_fields(:id)

      object      = collection.data.first
      washed_data = model.wash(request.data)

      response.fail('cannot find object')          if object.nil?
      response.fail(object.all_error_messages) unless object.valid?

      object.update(washed_data)

      # TODO: Sequel check to make sure save was ok
      # response.fail object.all_error_messages unless object.saved? && result

      response.status = 201
      response.add_data({ 'result' => 'ok' })

      response
    end

    delete '/:id' do
      logger.info "delete #{model.short_name} with id #{params[:id]}"

      add_filter :id, params[:id]

      collection = model.fetch_collection_for_request request

      response.fail "not found", 404 if collection.count == 0

      object = collection.first

      response.fail "failed to delete " + model.short_name unless obj.destroy

      response.status = 204

      response
    end
  end
end

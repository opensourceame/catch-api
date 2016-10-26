module API
  class Response
    def initialize(app)
      @app = app
    end

    def call(env)

      status, headers, response = @app.call(env)

      headers['Access-Control-Allow-Origin'] = '*'

      # binding.pry

      # catch sinatra errors

      if response.is_a?(Array)
        return [ status, headers, response ]
      end

      if response.data? or response.errors?
        return [ status, headers, [ response.get_data.to_json ] ]
      end

      # backwards compatibility for endpoints that do not return a rack response object
      return [ status, headers, response.body ]

    end

  end
end

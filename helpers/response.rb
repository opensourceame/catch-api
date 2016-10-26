module Sinatra
  class Response

    attr_accessor :data, :errors, :logger, :view, :request

    def initialize
      @data     = {}
      @errors   = []
      @logger   = nil
      @view     = nil
      super
    end

    def data?
      return true if @data.class.to_s[0..4] == 'Model'
      return ! @data.empty?
    end

    def add_data response_data
      @data.merge! response_data

      self
    end

    def set_data response_data
      @data = response_data

      self
    end

    def get_location(params = {})
      uri = Addressable::URI.new
      uri.query_values = request.params.merge(params)

      $config.urls.api + request.path + Addressable::URI.unescape(uri.to_s)
    end

    def set_collection(collection)

      logger.info "collection of " + data.count.to_s + " objects"

      locations             = {}
      locations['previous'] = get_location({'page' => collection.pager.previous})   unless collection.pager.current == collection.pager.previous
      locations['next']     = get_location({'page' => collection.pager.next})       unless collection.pager.next.nil?

      add_data({
        'result'        => 'ok',
        'pages'         => {
          'size'          => collection.pager.size,
          'current'       => collection.pager.current,
          'previous'      => collection.pager.previous,
          'next'          => collection.pager.next,
          'last'          => collection.pager.last,
        },
        'links'         => locations,
        'data'          => collection.data
      })

      self

    end

    def finish
      super
    end

    def add_error messages

      messages = [ messages ] if messages.is_a?(String)

      for message in messages
        message = message.downcase
        logger.warn 'error: ' + message
        @errors.push message
      end

      return @errors

    end

    def errors?
      return ! @errors.empty?
    end

    def fail error_messages = [], status_code = 400

      add_error error_messages if ! error_messages.empty?

      self.status  = status_code

      throw :halt, self
    end

    def get_data
      # return the object - this is for single collections
      if @data.is_a?(Object) and ! errors?
        return @data
      end

      return_data           = {}
      return_data['errors'] = @errors if errors?
      return_data.merge!(@data)
      return_data['md5sum'] = Digest::MD5.hexdigest return_data.to_s

      return_data
    end
  end
end

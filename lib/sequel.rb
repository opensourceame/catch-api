module Sequel
  module Collection
    class Query

      attr_reader :filters, :from, :limit, :pager

      @@value_map = {
        '='   => "=  '$value'",   # filter:id==1  <- note the double equals
        '<'   => "<  '$value'",
        '>'   => ">  '$value'",
        '['   => "<= '$value'",
        ']'   => ">= '$value'",
        '!'   => "!= '$value'",
        '*'   => 'IN ($value)',
        '~'   => "LIKE '%$value'",
      }

      def initialize
        @select   = ''
        @filters  = []
        @order    = [ 'id', 'order' ]
        @from     = ''
        @join     = []
        @limit    = 10
        @page     = 1
      end

      def parse_rack_request(request)

        for param in request.params

          if param[0][0..4] == 'order'
            field, direction = param[1].split(':')
            order(field, direction)
            next
          end

          if param[0] == 'limit'
            @limit = param[1].to_i
            next
          end

          if param[0] == 'page'
            @page = param[1].to_i
            next
          end

          if param[0][0..6] == 'filter:'
            add_filter param[0][7..-1], param[1]
            next
          end

        end
      end

      def parse_url(url)

        request = OpenStruct.new
        uri     = URI.parse(url)
        params  = []

        for part in uri.query.split('&')
          key, value = part.split('=')

          params.push([key, value])
        end

        request.params = params

        parse_rack_request request

      end

      def select(fields)
        @select = fields
      end

      def from(name)

        if name.is_a?(String)
          name[0] = name[0].upcase
          @from = "Models::#{name}".to_class
        end

        if name.is_a?(Class)
          @from = name
        end
      end

      def order(field, direction = 'asc')
        @order    = []
        @order[0] = field
        @order[1] = direction.to_sym == :desc ? 'reverse_order' : 'order'
      end

      def add_filter(object, value)

        type        = :filter
        subobjects  = object.match(/\./)

        # TODO: sub objects, e.g. filter:item.product.price=[100
        if subobjects
          binding.pry
        end

        object_first_char = object[0]
        value_first_char  = value[0]

        if object_first_char == '|'
          type = :or
          object = object[1..-1]
        end

        if @@value_map.has_key?(value_first_char)
          value     = value[1..-1]
          sql_value = @@value_map[value_first_char].gsub('$value', value)
        else
          # it's an equals
          sql_type  = '='
          sql_value = @@value_map['='].gsub('$value', value.to_s)
        end

        @filters.push(
          :type   => type,
          :value  =>  "#{object} #{sql_value}"
        )

      end

      def limit(limit)
        @limit = limit.to_i
      end

      def build

        dataset = @from

        for filter in filters
          dataset = dataset.send(filter[:type], filter[:value])
        end

        dataset = dataset.send(@order[1], @order[0].to_sym)

        dataset

      end

      def execute
        # build the query
        dataset = self.build.extension(:pagination)
        pager   = dataset.paginate(@page, @limit)

        @pager = OpenStruct.new({
          'size'      => @limit,
          'current'   => pager.current_page,
          'previous'  => pager.current_page > 1 ? pager.current_page - 1 : 1,
          'next'      => pager.next_page,
          'last'      => pager.page_count,
        })

        data = pager.all

        data
      end

    end
  end
end

module Sequel
  class Model

    # hack for backwards compatibilty with our old DM method
    def all_error_messages

      messages = []

      errors.each do |key, val|
        for message in val
          messages.push("#{key} #{message}")
        end
      end

      messages
    end

    def update_nested(data)

      data    = self.class.wash(data)

      data.delete('id')
      data.delete(:id)

      for field in self.columns
        send("#{field}=", data[field]) if data.has_key?(field)
      end

      data.each do |key, value|

        case value

        when Hash
          if self.respond_to?("#{key}_attributes=")
            self.send("#{key}_attributes=", value)
          else
            self[key] = value
          end

        when Array
          if self.respond_to?("#{key}_attributes=")
            self.send("#{key}_attributes=", value)
          else
            self[key] = value
          end

        end

      end

      self

    end

    def self.create(data)
      self.create_nested(data)
    end

    def self.create_nested(data)

      object  = self.new

      object.update_nested(data)

    end

    def self.create_nested_objects(data)

      data    = self.wash(data)
      object  = self.new

      for field in self.columns
        object[field] = data[field] if data.has_key?(field) rescue binding.pry
      end

      data.each do |key, value|

        case value
        when Array
          relationship  = association_reflection(key)
          related_model = relationship[:class_name].to_class

          for related_data in value
            child_object = related_model.create_nested(related_data)

            object.send(relationship[:name]).push(child_object)
          end

        when Hash
          relationship  = association_reflection(key)

          if relationship.nil?
            object[key] = value
          else
            related_model = relationship[:class_name].to_class
            child_object  = related_model.create_nested(value)
            object[key] = child_object
          end

        end

      end

      object

    end

    def self.wash data

      keys    = get_wash_keys data
      washed  = {}

      data.each do |key, value|

        key = key.to_sym

        if keys.member?(key)
          washed[key] = value
        end

        if associations.member?(key)

          relationship  = association_reflection key
          related_model = relationship[:class_name].to_class

          case relationship[:type]

          when :one_to_many

            if value.is_a?(Array)
               washed[key] = value.map!{ |child|
                               related_model.wash child
                             }
            else
              washed[key] = related_model.wash value
            end

          when :many_to_one
            washed[key] = related_model.wash value

          when :one_to_one
            washed[key] = related_model.wash value
          end

        end

      end

      washed

    end

private

    def self.get_wash_keys data

      symbolized = []

      for key in data.keys
        symbolized.push key.to_sym
      end

      symbolized & columns
    end

  end
end

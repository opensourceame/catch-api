require 'sequel/model'
require 'digest'

module Models

 module ModelInclusions

    # define accessors for all the columns in the schema.
    def self.included(klass)
      klass.set_dataset(klass.implicit_table_name)
      klass.send(:def_column_accessor, *klass.dataset.columns)
    end

    def to_json(*config)

      if config.is_a?(Array) && config.first.is_a?(Hash) && config.first.has_key?(:view)

        view = config.first[:view]
      else
        eval("view = $view_#{$$}")
      end

      options = { :naked => true }

      unless view.fields.nil?

        options[:only] = []

        for field in view.fields
          f = field.to_sym
          options[:only].push(f) if columns.member?(f)
        end

      end

      unless view.include.nil?
        options[:include] = [] unless options.has_key?(:include)
        for name in view.include
          name = name.split('.')[-1]
          options[:include].push(name) if self.respond_to?(name)
        end
      end

      unless view.related.nil?
        options[:include] = [] unless options.has_key?(:include)
        for name in view.related
          name = name.split('.')[-1]
          options[:include].push(name) if self.respond_to?(name)
        end
      end

      unless view.exclude.nil?
        options[:except] = view.exclude.map { |val| val.to_sym }
      end

      super options

    end

    def generate_key
      Digest::MD5.hexdigest(Time.now.to_s + Random.new.rand(1000000..99999999).to_s)
    end

  end


  module ModelExtensions

    def required_fields
      []
    end

    def factory(attrs = Hash.new, default_attrs = Hash.new)
          attrs  = default_attrs.merge(attrs)
          object = self.new

          attrs.each do |key, value|
            unless value.nil?
              value = value.is_a?(Proc) ? value.call : value
              object.send("#{key}=", value)
            end
          end

          return object
    end

    def fetch_collection_for_request(request)

      query = Sequel::Collection::Query.new
      query.from(self)
      query.parse_rack_request(request)

      collection = OpenStruct.new({
        'data'    => query.execute,
        'pager'   => query.pager,
      })

      collection

    end

    def short_name
      self.to_s.split(/::/)[-1]
    end

  end
end

module Rack::Session::Abstract
  class SessionHash
    def method_missing (name, *args, &block)

      if name.to_s[-1] == '='
        name = name[0 .. -2]

        self[name] = args[0]

        return true
      end

      return self[name] if self[name]
      return nil
    end
  end
end

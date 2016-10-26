module Sinatra
  class Request

    @data_parsed = false
    
    def view= view_data
      @view = view_data
    end
    
    def view
      return env['view']     
    end
    
    def client_ip
      return env['HTTP_X_REAL_IP'] if env.has_key?('HTTP_X_REAL_IP')
      
      ip        
    end
    
    def data
      
      parse_data unless data_parsed?
   
      @data
    end
     
    def data_parsed?
      return @data_parsed
    end
     
    def parse_data
      if get?
        @data = params
      else
        @data = JSON.parse(body.read) rescue params
      end
 
      @data_parsed = true
       
      @data
    end
    
    def set_param key, value
      parse_data unless data_parsed?

      @data[key] = value      
    end
    
    def merge_data extra_data
      @data = data.merge extra_data
    end
  end
end

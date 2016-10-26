module Endpoints
  class Locations < Base

    get '/' do
      response.set_data API::Locations.locations
    end
  end
end

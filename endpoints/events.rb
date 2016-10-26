module Endpoints
  class Events < Base

    set model: Event


    get '/' do

      events = Event.reverse_order(:id).limit(20).all

      response.set_data(events)
    end

  end
end

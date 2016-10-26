class User < Sequel::Model

  include   Models::ModelInclusions
  extend    Models::ModelExtensions

  def create_event(data)
    data[:user_id]  = self.id
    event           = Event.create(data).save
  end

end



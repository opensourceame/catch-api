
class User

  # include   Models::ModelInclusions
  # extend    Models::ModelExtensions

  attr_accessor :facebook_id, :first_name, :last_name, :type, :location, :transport, :money, :tickets

  alias_method :id, :facebook_id

  def self.get(id)

    redis = Redis.new
    user  = self.new
    json  = redis.get("amsterdam:users:#{id}")

    return nil if json.nil?

    data  = JSON.parse(json)

    data.each do |k, v|
      user.send("#{k}=", v)
    end

    user
  end

  def redis
    @redis ||= Redis.new
  end

  def new(data)
    data.each do |k, v|
      send("#{k}=", v)
    end
  end

  def save
    binding.pry
    redis.set("amsterdam:users:#{id}", self.to_json)
  end
end

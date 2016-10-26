# Load all endpoints

# base is required first
require File.dirname(__FILE__) + '/../endpoints/base.rb'

# Load all endpoints
Dir[File.dirname(__FILE__) + '/../endpoints/*.rb'].each { |file| require file }


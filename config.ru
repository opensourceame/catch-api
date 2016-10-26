# Amsterdam API

$PROGRAM_NAME = "Amsterdam API"
$LOAD_PATH.unshift(File.expand_path('..', __FILE__))

require File.expand_path('../init.rb', __FILE__)

require 'sinatra'
require 'rack/mount'
require 'rack/session/redis'

configure do
  set :logging, Logger::DEBUG
end


$stdout.sync = true
$stderr.sync = true

puts "*** Amsterdam API #{$config.version} started"
puts "*** environment is #{ENV['RACK_ENV']}"
puts "*** read config from #{$config.config_file}"

# Require local modules
require 'init/helpers'
require 'init/endpoints'
require 'init/middleware'

use API::Response
use Rack::Session::Redis, :sidbits => 32, :namespace => 'amsterdam:api:session', :key => 'amsterdam-api', :expire_after => 3600 * 24

# Map the rest of our endpoints
routes = Rack::Mount::RouteSet.new do |set|

  # plural endpoints that return collections of things
  set.add_route Endpoints::Locations,         :path_info => %r{^/locations}
  set.add_route Endpoints::Events,            :path_info => %r{^/events}
  set.add_route Endpoints::Users,             :path_info => %r{^/users}

  # singular endpoints
  set.add_route Endpoints::Ping,              :path_info => %r{^/$}
  set.add_route Endpoints::Ping,              :path_info => %r{^/ping}
  set.add_route Endpoints::Action,            :path_info => %r{^/action}
  set.add_route Endpoints::Auth,              :path_info => %r{^/auth}
  set.add_route Endpoints::Move,              :path_info => %r{^/move}
  set.add_route Endpoints::Reset,             :path_info => %r{^/reset}
  set.add_route Endpoints::Test,              :path_info => %r{^/test}
end

run routes

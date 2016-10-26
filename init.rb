#!/usr/bin/env ruby

if __FILE__ == $0
  puts "~ Running as a console."

  ENV['RACK_ENV']       ||= 'development'
end

require 'bundler'
require 'yaml'
require 'mysql2'
require 'sequel'
require 'slim'
require 'logger'
require 'redis'
require 'nokogiri'
require 'recursive-open-struct'

require_relative 'lib/hash_dig'
require_relative 'lib/sequel'

unless ENV.has_key?('RACK_ENV')
  abort "You have to set RACK_ENV!"
end

config_file = "config/common/config.yaml"

unless File.readable?(config_file)
  abort "!!! FATAL: cannot read config file #{config_file}"
end

require 'pry' if ENV['RACK_ENV'] == 'development'

config    = YAML.load_file(config_file)

$config               = RecursiveOpenStruct.new(config)
$config.config_file   = config_file
$config.version       = File.read(__dir__ + '/version.txt').chomp

DB = Sequel.connect($config.db.dsn)
DB.extension :connection_validator    if [ 'production' ].member?(ENV['RACK_ENV'])
DB.extension :looser_typecasting

Sequel.extension      :pagination
Sequel::Model.plugin  :json_serializer
Sequel::Model.plugin  :serialization_modification_detection
Sequel::Model.plugin  :nested_attributes
Sequel::Model.plugin  :serialization
Sequel::Model.plugin  :timestamps
Sequel::Model.plugin  :validation_helpers

# Require local modules
require_relative 'init/models'

if ARGV.first && File.file?(ARGV.first)
  load ARGV.first
end

require_relative 'lib/api'

API::Locations.logger = Logger.new(STDOUT)
API::Locations.parse_locations

# If run on its own rather than just being
# required it can be used as a Ruby console.
if __FILE__ == $0

  require 'pry'
  binding.pry
end

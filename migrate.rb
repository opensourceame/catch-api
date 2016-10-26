#!/usr/bin/env ./init.rb

require 'mysql2'
require 'addressable/uri'

# Load the migration extension.
Sequel.extension(:migration)

uri     = URI.parse(DB.uri)
db_name = uri.path[1..-1]

if ARGV.include?('--recreate')
  puts "~ Recreating the database."
  DB.query("DROP database IF EXISTS #{db_name}")
end

# binding.pry

DB.execute("CREATE DATABASE IF NOT EXISTS #{db_name}")

# Run migrations defined in the migrations directory.
puts "~ Running migrations from the migration directory."
Sequel::Migrator.run(DB, 'migrations', use_transactions: true)

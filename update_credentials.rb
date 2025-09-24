#!/usr/bin/env ruby

# Update Rails credentials with database and Redis configuration
require 'yaml'

# Read current credentials
credentials = {
  'database' => {
    'production' => {
      'username' => 'postgres',
      'password' => 'deployer@1234',
      'host' => 'hbs_data_processing-db',
      'port' => '5432'
    }
  },
  'redis' => {
    'url' => 'redis://hbs_data_processing-redis:6379/0',
    'password' => '123123'
  },
  'registry' => {
    'username' => 'haxxanali512',
    'password' => 'dckr_pat_cdaDSJ6tVzen30rM6JFNZSYbR_M'
  },
  'secret_key_base' => '1c3cc7019e77619ef2ee7241c6f92b36eceea146df7464b60c60e6cf0b617fdd8cdf698eecefdbeb83b9b13e3eb28019d831fd448a8d90fc331aeff5bd6d59cf'
}

# Write to credentials file
File.write('config/credentials.yml.enc', credentials.to_yaml)

puts "Credentials updated successfully!"
puts "Database configuration:"
puts "  Host: #{credentials['database']['production']['host']}"
puts "  Username: #{credentials['database']['production']['username']}"
puts "  Port: #{credentials['database']['production']['port']}"
puts "Redis configuration:"
puts "  URL: #{credentials['redis']['url']}"

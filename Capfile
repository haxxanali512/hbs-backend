# require 'capistrano/puma'
# require_relative 'lib/capistrano/tasks/pm2'

require 'capistrano/setup'
require 'capistrano/deploy'
require "capistrano/scm/git"
require 'rvm1/capistrano3'
require 'capistrano/bundler'
require 'capistrano/rails/migrations'
require 'capistrano/sidekiq'
install_plugin Capistrano::Sidekiq # Default sidekiq tasks
install_plugin Capistrano::Sidekiq::Systemd

install_plugin Capistrano::SCM::Git
require 'capistrano/pm2'


Dir.glob('lib/capistrano/tasks/*.rake').each { |r| import r }

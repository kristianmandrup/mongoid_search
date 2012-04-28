require 'simplecov'
SimpleCov.start

$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

# require 'mongo'
require 'moped'
require 'mongoid'
require 'hashie'
require 'database_cleaner'
require 'fast_stemmer'
require 'yaml'
require 'mongoid_search'
require "lingua/stemmer"

module Mongoid
  def self.database
    Mongoid::Sessions.default
  end

  def self.collections
    database["system.namespaces"].find(name: { "$not" => /system|\$/ }).to_a
  end
end

module Moped
  class Session
    def collections
      Hashie::Mash.new Mongoid.collections
    end
  end
end

Mongoid.configure do |config|
  name = "mongoid_search_test"

  if defined?(Moped)
    session = Moped::Session.new %w[127.0.0.1:27017]
    session.use name
    config.connect_to name
  else
    config.master = Mongo::Connection.new.db(name)
  end
end

Dir["#{File.dirname(__FILE__)}/models/*.rb"].each { |file| require file }

DatabaseCleaner.orm = :mongoid

RSpec.configure do |config|
  config.before(:all) do
    DatabaseCleaner.strategy = :truncation
  end

  config.before(:each) do
    DatabaseCleaner.start
  end

  config.after(:each) do
    DatabaseCleaner.clean
  end
end

# frozen_string_literal: true

require "simplecov"
SimpleCov.start do
  enable_coverage :branch
  minimum_coverage line: 100, branch: 100

  skip "/spec/"
  skip "/db/"
  skip "Rakefile"
  skip "config.ru"
end

ENV["DATABASE_URL"] ||= "postgres://localhost:5432/resource_api_test"

require "sequel"
Sequel.extension :migration

DB = Sequel.connect(ENV.fetch("DATABASE_URL"))
Sequel::Migrator.run(DB, File.expand_path("../db/migrations", __dir__))

require "rack/test"
require_relative "../app"

module RackTestApp
  def app
    ResourceApi
  end
end

RSpec.configure do |config|
  config.include Rack::Test::Methods
  config.include RackTestApp

  config.before do
    header "Host", "localhost"
    DB[:resources].delete
  end
end

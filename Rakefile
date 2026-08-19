require "sequel"

namespace :db do
  task :connect do
    require "dotenv/load"
    @db = Sequel.connect(ENV.fetch("DATABASE_URL"))
  end

  desc "Run migrations"
  task migrate: :connect do
    Sequel.extension :migration
    Sequel::Migrator.run(@db, "db/migrations")
  end
end

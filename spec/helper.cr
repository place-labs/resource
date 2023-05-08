require "spec"
require "../src/placeos-resource"
require "action-controller/logger"

Spec.before_suite do
  PgORM::Database.parse(ENV["PG_DATABASE_URL"])
  PgORM::Database.connection do |db|
    db.exec "DROP TABLE IF EXISTS basic;"
    db.exec <<-SQL
    CREATE TABLE basic (
      id BIGSERIAL NOT NULL PRIMARY KEY,
      name TEXT NOT NULL
    );
    SQL
  end
  Log.builder.bind("*", backend: ActionController.default_backend, level: Log::Severity::Info)
end

class Basic < PgORM::Base
  attribute name : String
end

class Processor < PlaceOS::Resource(Basic)
  getter creates = [] of String
  getter updates = [] of String
  getter deletes = [] of String

  property? reconnected = false

  def on_reconnect
    self.reconnected = true
  end

  def process_resource(action : PlaceOS::Resource::Action, resource : Basic) : PlaceOS::Resource::Result
    case action
    in .created? then creates
    in .updated?
      raise "no change detected!!" unless resource.name_changed?
      updates
    in .deleted? then deletes
    end << resource.name

    PlaceOS::Resource::Result::Success
  end
end

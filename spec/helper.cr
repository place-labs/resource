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
  attribute id : Int64
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

# Processor that raises from inside `_spawn_event` for the first `fault_quota`
# invocations, used to verify the dispatch loop survives consecutive errors
# without blowing the worker fiber stack.
class FaultyProcessor < PlaceOS::Resource(Basic)
  getter creates = [] of String
  getter spawn_calls = Atomic(Int32).new(0)
  getter faults_emitted = Atomic(Int32).new(0)
  property fault_quota : Int32 = 0

  def process_resource(action : PlaceOS::Resource::Action, resource : Basic) : PlaceOS::Resource::Result
    creates << resource.name if action.created?
    PlaceOS::Resource::Result::Success
  end

  private def _spawn_event(event)
    spawn_calls.add(1)
    if faults_emitted.get < fault_quota
      faults_emitted.add(1)
      raise "injected fault"
    end
    spawn { _process_event(event) }
    Fiber.yield
  end
end

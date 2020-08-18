require "spec"
require "../src/placeos-resource"

require "action-controller/logger"
require "rethinkdb-orm"

Spec.before_suite do
  Basic.clear
  Log.builder.bind("*", backend: ActionController.default_backend, level: Log::Severity::Debug)
end

class Basic < RethinkORM::Base
  attribute name : String
end

class Processor < PlaceOS::Resource(Basic)
  getter creates = [] of String
  getter updates = [] of String
  getter deletes = [] of String

  def process_resource(action : PlaceOS::Resource::Action, resource : Basic) : PlaceOS::Resource::Result
    case action
    in PlaceOS::Resource::Action::Created
      creates << resource.name
    in PlaceOS::Resource::Action::Updated
      updates << resource.name
    in PlaceOS::Resource::Action::Deleted
      deletes << resource.name
    end

    PlaceOS::Resource::Result::Success
  end
end

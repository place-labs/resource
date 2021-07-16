require "deque"
require "json"
require "log_helper"
require "promise"
require "rethinkdb-orm"
require "retriable"

# Internally abstracts data event streams.
#
abstract class PlaceOS::Resource(T)
  Log = ::Log.for(self)

  alias Action = RethinkORM::Changefeed::Event

  record Event(T), action : Action, resource : T

  record Error, name : String, reason : String do
    include JSON::Serializable

    def initialize(name, reason)
      @name = name || ""
      @reason = reason || ""
    end
  end

  class ProcessingError < Exception
    getter name

    def initialize(@name : String?, @message : String?, @cause : Exception? = nil)
      super(@message, @cause)
    end

    def to_error : Error
      Error.new(name, message || cause.try &.message)
    end
  end

  # Outcome of processing a resource
  enum Result
    Success
    Error
    Skipped
  end

  # Errors generated while processing resources
  # Mainly for inspection while testing.
  getter errors : Array(Error) = [] of Error
  private getter error_buffer_size = 50

  private getter channel_buffer_size
  private getter processed_buffer_size

  # Buffer of recently processed elements
  # NOTE: rw lock?
  getter processed : Deque(Event(T))
  private getter event_channel : Channel(Event(T))

  abstract def process_resource(action : Action, resource : T) : Result

  def initialize(@processed_buffer_size : Int32 = 64, @channel_buffer_size : Int32 = 64)
    @processed = Deque(Event(T)).new(processed_buffer_size)
    @event_channel = Channel(Event(T)).new(channel_buffer_size)
  end

  def start : self
    processed.clear
    errors.clear
    @event_channel = Channel(Event(T)).new(channel_buffer_size) if event_channel.closed?

    # Listen for changes on the resource table
    spawn(same_thread: true) { watch_resources }

    # Load all the resources into a channel
    load_resources

    # Begin background processing
    spawn(same_thread: true) { watch_processing }

    Fiber.yield

    self
  end

  def stop : self
    event_channel.close
    self
  end

  # Load all resources from the database, push into a channel
  #
  private def load_resources : Int64
    count = Atomic(Int64).new(0)
    waiting = Array(Promise::DeferredPromise(Nil)).new(channel_buffer_size)
    T.all.in_groups_of(channel_buffer_size, reuse: true) do |resources|
      resources.each do |resource|
        next unless resource
        event = Event.new(action: Action::Created, resource: resource)
        waiting << Promise.defer(same_thread: true) do
          count.add(1)
          _process_event(event)
          nil
        end
      end
      Promise.all(waiting).get
      waiting.clear
    end

    total = count.get
    Log.info { {message: "loaded #{total}", type: T.name, handler: self.class.name} }
    total
  end

  # Listen to changes on the resource table
  #
  private def watch_resources
    Log.context.set({
      type:    T.name,
      handler: self.class.name,
    })

    Retriable.retry(base_interval: 1.milliseconds, max_interval: 1.seconds) do
      begin
        T.changes.each do |change|
          break if event_channel.closed?

          Log.trace { {message: "resource event", event: change.event.to_s.downcase, id: change.value.id} }
          event_channel.send(Event(T).new(change.event, change.value))
        end
      rescue e
        Log.error { {message: "while watching resources", error: e.to_s} } unless e.is_a?(Channel::ClosedError)
        raise e
      end
    end
  end

  # Consumes resources ready for processing
  #
  private def watch_processing
    loop do
      event = event_channel.receive
      spawn(same_thread: true) { _process_event(event) }
      Fiber.yield
    end
  rescue e
    unless e.is_a?(Channel::ClosedError)
      Log.error(exception: e) { "error while consuming resource event queue" }
      watch_processing
    end
  end

  # Process the event, place into the processed buffer
  #
  private def _process_event(event : Event(T)) : Nil
    Log.context.set({
      type:    T.name,
      handler: self.class.name,
      action:  event.action.to_s,
      id:      event.resource.id,
    })

    Log.trace { "processing event" }
    begin
      case process_resource(event.action, event.resource)
      in .success?
        processed.push(event)
        processed.shift if processed.size > processed_buffer_size
        Log.trace { "processed event" }
      in .skipped? then Log.info { "processing skipped" }
      in .error?   then Log.warn { {message: "processing failed", resource: event.resource.to_json} }
      end
    rescue e : ProcessingError
      Log.warn(exception: e) { {message: "processing failed", error: "#{e.name}: #{e.message}"} }
      while errors.size >= error_buffer_size
        errors.shift?
      end
      errors << e.to_error
    end
  rescue e
    Log.error(exception: e) { {message: "unexpected error while processing event", resource: event.resource.to_json} }
  end
end

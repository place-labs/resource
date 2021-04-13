require "deque"
require "log_helper"
require "promise"
require "rethinkdb-orm"
require "simple_retry"

# Internally abstracts data event streams.
#
abstract class PlaceOS::Resource(T)
  Log = ::Log.for(self)

  alias Error = NamedTuple(name: String, reason: String)
  alias Action = RethinkORM::Changefeed::Event

  class ProcessingError < Exception
    getter name

    def initialize(@name : String?, @message : String?, @cause : Exception? = nil)
      super(@message, @cause)
    end

    def to_error
      {name: name || "", reason: message || cause.try &.message || ""}
    end
  end

  # TODO: Uncomment when crystal supports generic aliases
  # alias Event = NamedTuple(action: Action, resource: T)

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
  getter processed : Deque(NamedTuple(action: Action, resource: T))
  private getter event_channel : Channel(NamedTuple(action: Action, resource: T))

  abstract def process_resource(action : Action, resource : T) : Result

  def initialize(
    @processed_buffer_size : Int32 = 64,
    @channel_buffer_size : Int32 = 64
  )
    @event_channel = Channel(NamedTuple(action: Action, resource: T)).new(channel_buffer_size)
    @processed = Deque(NamedTuple(action: Action, resource: T)).new(processed_buffer_size)
  end

  def start : self
    processed.clear
    errors.clear
    @event_channel = Channel(NamedTuple(action: Action, resource: T)).new(channel_buffer_size) if event_channel.closed?

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

  private def consume_event : NamedTuple(action: Action, resource: T)
    event_channel.receive
  end

  # Load all resources from the database, push into a channel
  #
  private def load_resources : UInt64
    count = 0_u64
    waiting = Array(Promise::DeferredPromise(Nil)).new(channel_buffer_size)
    T.all.in_groups_of(channel_buffer_size, reuse: true).each do |resources|
      resources.each do |resource|
        next unless resource
        event = {action: Action::Created, resource: resource}
        waiting << Promise.defer(same_thread: true) do
          count += 1
          _process_event(event)
        end
      end
      Promise.all(waiting).get
      waiting.clear
    end

    Log.info { {message: "loaded #{count} #{T} resources", type: T.name, handler: self.class.name} }
    count
  end

  # Listen to changes on the resource table
  #
  private def watch_resources
    Log.context.set({
      type:    T.name,
      handler: self.class.name,
    })

    SimpleRetry.try_to(base_interval: 1.milliseconds, max_interval: 1.seconds) do
      begin
        T.changes.each do |change|
          break if event_channel.closed?

          action = change[:event]
          resource = change[:value]

          event = {
            action:   action,
            resource: resource,
          }

          Log.debug { {message: "resource event", action: action.to_s, id: resource.id} }
          event_channel.send(event)
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
      event = consume_event
      spawn(same_thread: true) { _process_event(event) }
      Fiber.yield
    end
  rescue e
    unless e.is_a?(Channel::ClosedError)
      Log.error(exception: e) { {message: "error while consuming resource event queue"} }
      watch_processing
    end
  end

  # Process the event, place into the processed buffer
  #
  private def _process_event(event : NamedTuple(action: Action, resource: T)) : Nil
    Log.context.set({
      type:    T.name,
      handler: self.class.name,
      action:  event[:action].to_s,
      id:      event[:resource].id,
    })

    Log.debug { "processing event" }
    begin
      case process_resource(**event)
      in .success?
        processed.push(event)
        processed.shift if processed.size > @processed_buffer_size
        Log.info { "processed event" }
      in .skipped? then Log.info { "processing skipped" }
      in .error?   then Log.warn { {message: "processing failed", resource: event[:resource].to_json} }
      end
    rescue e : ProcessingError
      Log.warn(exception: e) { {message: "processing failed", error: "#{e.name}: #{e.message}"} }
      while errors.size >= error_buffer_size
        errors.shift?
      end
      errors << e.to_error
    end
  rescue e
    Log.error(exception: e) { {message: "unexpected error while processing event", resource: event[:resource].inspect} }
  end
end

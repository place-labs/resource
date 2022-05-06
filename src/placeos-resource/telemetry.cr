module OpenTelemetry::Instrumentation
  class PlaceOSResource < OpenTelemetry::Instrumentation::Instrument
  end
end

abstract class PlaceOS::Resource(T)
  trace("load_resources") do
    OpenTelemetry.trace.in_span("#{self.class.name} Load Resources") do
      previous_def
    end
  end

  trace("start") do
    OpenTelemetry.trace.in_span("#{self.class.name} Start") do
      previous_def
    end
  end

  macro inherited
    trace("process_event") do
      OpenTelemetry.trace.in_span("#{self.class.name} Process Event") do
        previous_def
      end
    end
  end
end

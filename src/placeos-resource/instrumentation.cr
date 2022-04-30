require "defined"

# This allows opt-out of specific instrumentation at compile time, via environment variables.
# Refer to https://wyhaines.github.io/defined.cr/ for details about all supported check types.
unless_enabled?("OTEL_CRYSTAL_DISABLE_INSTRUMENTATION_PLACEOS_RESOURCE") do
  if_defined?(OpenTelemetry::Instrumentation::Instrument) do
    module OpenTelemetry::Instrumentation
      class PlaceOSResource < OpenTelemetry::Instrumentation::Instrument
      end
    end

    abstract class PlaceOS::Resource(T)
      trace("start") do
        trace = OpenTelemetry.trace
        trace_name = "#{self.class.name} Start"
        trace.in_span(trace_name) do
          previous_def
        end
      end

      trace("_process_event") do
        trace = OpenTelemetry.trace
        trace_name = "#{self.class.name} Process Event"
        trace.in_span(trace_name) do
          previous_def
        end
      end
    end
  end
end

module EventSourcery
  NonSequentialEventProcessingError = Class.new(StandardError)

  class ProcessedEventTracker
    def initialize(storage_adapter)
      @storage_adapter = storage_adapter
    end

    def setup(*args)
      @storage_adapter.setup(*args)
    end

    def processed_event(processor_name, event_id)
      @storage_adapter.processed_event(processor_name, event_id)
    end

    def reset_last_processed_event_id(processor_name)
      @storage_adapter.reset_last_processed_event_id(processor_name)
    end

    def last_processed_event_id(processor_name)
      @storage_adapter.last_processed_event_id(processor_name)
    end

    def tracked_processors
      @storage_adapter.tracked_processors
    end
  end
end

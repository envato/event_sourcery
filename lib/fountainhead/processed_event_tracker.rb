module Fountainhead
  NonSequentialEventProcessingError = Class.new(StandardError)

  class ProcessedEventTracker
    def initialize(storage_adapter)
      @storage_adapter = storage_adapter
    end

    extend Forwardable
    def_delegators :@storage_adapter, :setup,
                                      :processed_event,
                                      :reset_last_processed_event_id,
                                      :last_processed_event_id,
                                      :tracked_processors
  end
end

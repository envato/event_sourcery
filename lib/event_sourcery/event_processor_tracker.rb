module EventSourcery
  class EventProcessorTracker
    def initialize(storage_adapter)
      @storage_adapter = storage_adapter
    end

    extend Forwardable
    def_delegators :@storage_adapter, :setup,
                                      :processed_event,
                                      :reset_last_processed_event_id,
                                      :last_processed_event_id,
                                      :tracked_processors,
                                      :processing_event
  end
end

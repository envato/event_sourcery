module EventSourcery
  Error = Class.new(StandardError)
  UnableToLockProcessorError = Class.new(Error)
  UnableToProcessEventError = Class.new(Error)
  ConcurrencyError = Class.new(Error)
  AtomicWriteToMultipleAggregatesNotSupported = Class.new(Error)

  class EventProcessingError < Error
    attr_reader :event

    def initialize(event)
      @event = event
    end
  end
end

module EventSourcery
  Error = Class.new(StandardError)
  UnableToLockProcessorError = Class.new(Error)
  UnableToProcessEventError = Class.new(Error)
  ConcurrencyError = Class.new(Error)
  AtomicWriteToMultipleAggregatesNotSupported = Class.new(Error)

  class EventProcessingError < Error
    attr_reader :event, :original_error

    def initialize(event, original_error)
      @event = event
      @original_error = original_error
    end
  end
end

module EventSourcery
  Error = Class.new(StandardError)
  UnableToLockProcessorError = Class.new(Error)
  UnableToProcessEventError = Class.new(Error)
  ConcurrencyError = Class.new(Error)
  AtomicWriteToMultipleAggregatesNotSupported = Class.new(Error)

  class EventProcessingError < Error
    attr_reader :event, :processor

    def initialize(event:, processor:)
      @event = event
      @processor = processor
    end

    def message
      parts = []
      parts << "#<#{processor.class} @@processor_name=#{processor.processor_name.inspect}>"
      parts << "#<#{event.class} @id=#{event.id.inspect}, @uuid=#{event.uuid.inspect}, @type=#{event.type.inspect}>"
      parts << "#<#{cause.class}: #{cause.message}>"
      parts.join("\n") + "\n"
    end
  end
end

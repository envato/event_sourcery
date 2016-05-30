module EventSourcery
  UnableToLockProcessorError = Class.new(StandardError)
  ConcurrencyError = Class.new(StandardError)
end

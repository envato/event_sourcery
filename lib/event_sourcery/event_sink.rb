module EventSourcery
  class EventSink
    def initialize(adapter)
      @adapter = adapter
    end

    extend Forwardable
    def_delegators :adapter, :sink

    private

    attr_reader :adapter
  end
end

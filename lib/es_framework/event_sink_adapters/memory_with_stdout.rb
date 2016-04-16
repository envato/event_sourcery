module ESFramework
  module EventSinkAdapters
    class MemoryWithStdOut < Memory
      def initialize(events = [], io = STDOUT)
        super(events)
        @io = io
      end

      def sink(aggregate_id:, type:, body:)
        @io.puts "#{aggregate_id},#{type},#{JSON.dump(body)}"
        super
      end
    end
  end
end

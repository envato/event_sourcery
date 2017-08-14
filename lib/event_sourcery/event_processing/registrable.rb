module EventSourcery
  module EventProcessing
    module Registrable
      def self.included(base)
        EventSourcery.event_stream_processor_registry.register(base)
        base.extend(ClassMethods)
        base.include(InstanceMethods)
      end

      module ClassMethods
        # Set the group name the processor belongs to.
        # Returns "default" if no group name is given.
        #
        # @param processor_group [String] the name of the group processor belongs to
        def processor_group(processor_group = nil)
          if processor_group
            @processor_group = processor_group
          else
            (defined?(@processor_group) && @processor_group) || 'default'
          end
        end

        # Set the name of the processor.
        # Returns the class name if no name is given.
        #
        # @param name [String] the name of the processor to set
        def processor_name(name = nil)
          if name
            @processor_name = name
          else
            (defined?(@processor_name) && @processor_name) || self.name
          end
        end
      end

      module InstanceMethods
        # Calls processor_name method on the instance class
        def processor_name
          self.class.processor_name
        end

        # Calls processor_group method on the instance class
        def processor_group
          self.class.processor_group
        end
      end

    end
  end
end

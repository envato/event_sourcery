module EventSourcery
  module EventProcessing
    module TableOwner
      DefaultTableError = Class.new(StandardError)
      NoSuchTableError = Class.new(StandardError)

      def self.prepended(base)
        base.extend(ClassMethods)
      end

      module ClassMethods
        def tables
          @tables ||= {}
        end

        def table(name, &block)
          tables[name] = block
        end
      end

      def setup
        self.class.tables.each do |table_name, schema_block|
          prefixed_name = table_name_prefixed(table_name)
          @db_connection.create_table?(prefixed_name, &schema_block)
        end
        super if defined?(super)
      end

      def reset
        self.class.tables.keys.each do |table_name|
          prefixed_name = table_name_prefixed(table_name)
          if @db_connection.table_exists?(prefixed_name)
            @db_connection.drop_table(prefixed_name, cascade: true)
          end
        end
        super if defined?(super)
        setup
      end

      def truncate
        self.class.tables.each do |table_name, _|
          @db_connection.transaction do
            prefixed_name = table_name_prefixed(table_name)
            @db_connection[prefixed_name].truncate
            tracker.reset_last_processed_event_id(self.class.processor_name)
          end
        end
      end

      private

      attr_reader :db_connection
      attr_accessor :table_prefix

      def table(name = nil)
        if name.nil? && self.class.tables.length != 1
          raise DefaultTableError, 'You must specify table name when when 0 or multiple tables are defined'
        end

        name ||= self.class.tables.keys.first

        unless self.class.tables[name.to_sym]
          raise NoSuchTableError, "There is no table with the name '#{name}' defined"
        end

        db_connection[table_name_prefixed(name)]
      end

      def table_name_prefixed(name)
        [table_prefix, name].compact.join("_").to_sym
      end
    end
  end
end

module EventSourcery
  module Postgres
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
          @db_connection.create_table?(table_name, &schema_block)
        end
        super if defined?(super)
      end

      def reset
        self.class.tables.keys.each do |table_name|
          if @db_connection.table_exists?(table_name)
            @db_connection.drop_table(table_name, cascade: true)
          end
        end
        super if defined?(super)
        setup
      end

      def truncate
        self.class.tables.each do |table_name, _|
          @db_connection.transaction do
            @db_connection[table_name].truncate
            tracker.reset_last_processed_event_id(self.class.processor_name)
          end
        end
      end

      private

      attr_reader :db_connection

      def table(name = nil)
        if name.nil? && self.class.tables.length != 1
          raise DefaultTableError, 'You must specify table name when when 0 or multiple tables are defined'
        end

        name ||= self.class.tables.keys.first

        unless self.class.tables[name.to_sym]
          raise NoSuchTableError, "There is no table with the name '#{name}' defined"
        end

        db_connection[name]
      end
    end
  end
end

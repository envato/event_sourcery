module EventSourcery
  module EventProcessing
    module TableOwner
      DefaultTableError = Class.new(StandardError)

      def self.prepended(base)
        base.extend(ClassMethods)
      end

      module ClassMethods
        def tables
          @tables ||= {}
        end

        def table(name, &block)
          tables[name] =  block
        end
      end

      def setup
        self.class.tables.each do |table_name, schema_block|
          @db_connection.create_table?(table_name, &schema_block)
        end
      end

      def reset
        self.class.tables.keys.each do |table_name|
          if @db_connection.table_exists?(table_name)
            @db_connection.drop_table(table_name)
          end
        end
        setup
      end

      private

      attr_reader :db_connection

      def table
        @table ||= begin
                     unless self.class.tables.length == 1
                       raise DefaultTableError, 'Default table cannot be used when 0 or multiple tables are defined'
                     end
                     db_connection[self.class.tables.keys.first]
                   end
      end
    end
  end
end

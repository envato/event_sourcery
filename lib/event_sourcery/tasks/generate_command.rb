require 'thor'

module EventSourcery
  module Tasks
    class GenerateCommand < Thor::Group
      include Thor::Actions

      argument :aggregate
      argument :command
      argument :event

      def self.source_root
        File.dirname(__FILE__)
      end

      def create_aggregate_file
        template('templates/aggregate.tt', "command/#{aggregate}/aggregate.rb")
      end

      def create_respository_file
        template('templates/repository.tt', "command/#{aggregate}/repository.rb")
      end

      def create_command_handler_file
        template('templates/command_handler.tt', "command/#{aggregate}/#{command}/command_handler.rb")
      end
    end
  end
end

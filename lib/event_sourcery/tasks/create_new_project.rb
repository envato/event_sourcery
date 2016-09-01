module EventSourcery
  module Tasks
    class CreateNewProject < Thor::Group
      include Thor::Actions

      argument :project_name

      def self.source_root
        File.dirname(__FILE__)
      end

      def create_gemfile
        template('templates/gemfile.tt', "#{project_name}/Gemfile")
      end

      def create_rakefile
        template('templates/rakefile.tt', "#{project_name}/Rakefile")
      end

      def bundle_install
        inside project_name do
          run('bundle install')
        end
      end
    end
  end
end

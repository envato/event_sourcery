require 'thor'

require 'event_sourcery/tasks/create_new_project'
require 'event_sourcery/tasks/generate_command'

module EventSourcery
  class CLI < Thor
    register(Tasks::CreateNewProject, 'new', 'new [PROJECT NAME]', 'Creates a new EventSourcery project')
    register(Tasks::GenerateCommand, 'generate:command', 'generate:command [AGGREGATE] [COMMAND] [EVENT]', 'Generates a new COMMAND for AGGREGATE to create EVENT')
  end
end

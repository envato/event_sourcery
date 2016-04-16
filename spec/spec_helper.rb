$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'fountainhead'
require 'pry'

Dir.glob(File.dirname(__FILE__) + '/support/**/*.rb') { |f| require f }

RSpec.configure do |config|
  config.disable_monkey_patching!
end

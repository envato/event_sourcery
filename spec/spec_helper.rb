$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'event_sourcery'
require 'pry'
require 'event_sourcery/rspec/event_store_shared_examples'

Dir.glob(File.dirname(__FILE__) + '/support/**/*.rb') { |f| require f }

RSpec.configure do |config|
  config.disable_monkey_patching!

  config.mock_with :rspec do |mocks|
    # Prevents you from mocking or stubbing a method that does not exist on
    # a real object. This is generally recommended, and will default to
    # `true` in RSpec 4.
    mocks.verify_partial_doubles = true
  end
end

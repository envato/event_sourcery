require 'spec_helper'

RSpec.describe EventSourcery do
  it 'has a version number' do
    expect(EventSourcery::VERSION).not_to be nil
  end
end

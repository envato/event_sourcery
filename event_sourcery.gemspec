# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'event_sourcery/version'

Gem::Specification.new do |spec|
  spec.name          = 'event_sourcery'
  spec.version       = EventSourcery::VERSION
  spec.authors     = ['Envato']
  spec.email       = ['rubygems@envato.com']

  spec.summary       = 'Event Sourcing Library'
  spec.description   = ''
  spec.homepage      = 'https://github.com/envato/event_sourcery'
  spec.license       = 'MIT'
  spec.metadata      = {
    'allowed_push_host' => 'https://rubygems.org',
    'bug_tracker_uri' => "#{spec.homepage}/issues",
    'changelog_uri' => "#{spec.homepage}/blob/HEAD/CHANGELOG.md",
    'documentation_uri' => "https://www.rubydoc.info/gems/event_sourcery/#{spec.version}",
    'source_code_uri' => "#{spec.homepage}/tree/v#{spec.version}"
  }

  spec.files = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(\.|Gemfile|Rakefile|bin/|script/|spec/)})
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.required_ruby_version = '>= 2.6.0'

  spec.add_runtime_dependency 'logger'

  spec.add_development_dependency 'benchmark-ips'
  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'pry'
  spec.add_development_dependency 'rake', '~> 13'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'rubocop', '~> 1'
end

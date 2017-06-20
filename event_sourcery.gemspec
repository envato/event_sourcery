# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
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

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.required_ruby_version = '>= 2.2.0'

  spec.add_development_dependency 'bundler', '~> 1.10'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'pry'
  spec.add_development_dependency 'benchmark-ips'
end

# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'event_sourcery/version'

Gem::Specification.new do |spec|
  spec.name          = "event_sourcery"
  spec.version       = EventSourcery::VERSION
  spec.authors     = ["Steve Hodgkiss", "Tao Guo", "Sebastian von Conrad"]
  spec.email       = ["steve@hodgkiss.me", "tao.guo@envato.com", "sebastian.von.conrad@envato.com"]

  spec.summary       = %q{Event Sourcing Library}
  spec.description   = %q{}
  spec.homepage      = ""

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.required_ruby_version = '>= 2.1.0'

  spec.add_dependency 'sequel', '~> 4.38'
  spec.add_dependency 'pg'
  spec.add_development_dependency "bundler", "~> 1.10"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "pry"
  spec.add_development_dependency "benchmark-ips"
end

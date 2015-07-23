# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'rack/scriptstacker/version'

Gem::Specification.new do |spec|
  spec.name          = 'rack-scriptstacker'
  spec.version       = Rack::ScriptStacker::VERSION
  spec.authors       = ['Max Cantor']
  spec.email         = ['max@maxcantor.net']
  spec.summary       = %q{Quickly inject static file lists into served HTML.}
  spec.homepage      = 'http://github.com/mcantor/rack-scriptstacker'
  spec.license       = 'WTFPL'

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'rack', '~> 1.6'
  spec.add_dependency 'cantrips'

  spec.add_development_dependency 'bundler', '~> 1.10'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rspec'
end

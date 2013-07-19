# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'moped_mapping/version'

Gem::Specification.new do |spec|
  spec.name          = "moped_mapping"
  spec.version       = MopedMapping::VERSION
  spec.authors       = ["akima"]
  spec.email         = ["akm2000@gmail.com"]
  spec.description   = %q{make mapping from moped collection object to MongoDB actual collection by using Hash}
  spec.summary       = %q{make mapping from moped collection object to MongoDB actual collection by using Hash}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]
  spec.add_dependency "moped", "~> 1.5.0"

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "tengine_support"
end

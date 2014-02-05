# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'turkish_stemmer/version'

Gem::Specification.new do |spec|
  spec.name          = "turkish_stemmer"
  spec.version       = TurkishStemmer::VERSION
  spec.authors       = ["Tasos Stathopoulos", "Giorgos Tsiftsis"]
  spec.email         = ["stathopa@skroutz.gr", "giorgos.tsiftsis@skroutz.gr"]
  spec.summary       = %q{A simple turkish stemmer}
  spec.description   = %q{A simple turkish stemmer}
  spec.homepage      = "https://gitlab.skroutz.gr/turkish_stemmer"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.5"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec"
end

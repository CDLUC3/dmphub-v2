# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'dmp/json_validator/version'

Gem::Specification.new do |spec|
  spec.required_ruby_version       = '2.7.6'
  spec.name                        = 'dmp-json_validator'
  spec.version                     = Dmp::JsonValidator::VERSION
  spec.summary                     = 'DMP JSON validation for the DMPHub'
  spec.authors                     = ['briri']
  spec.email                       = 'briley@ucop.edu'
  spec.files                       = ['lib/dmp/json_validator.rb']
  spec.license                     = 'MIT'
  spec.homepage                    = 'https://github.com/CDLUC3/dmphub-v2/gems/dmp-json_validator'

  spec.metadata['source_code_uri'] = 'https://github.com/CDLUC3/dmphub-v2/gems/dmp-json_validator'

  spec.add_dependency 'json-schema', '~> 3.0'

  spec.add_development_dependency 'rspec', '~> 3.11'
  spec.add_development_dependency 'rubocop', '~> 1.29'
end

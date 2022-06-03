# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'dmp/response_formatter/version'

Gem::Specification.new do |spec|
  spec.required_ruby_version       = '~> 2.7'
  spec.name                        = 'dmp-response_formatter'
  spec.version                     = Dmp::S3Adapter::VERSION
  spec.summary                     = 'DMP utility that converts a DMP record into various formats'
  spec.authors                     = ['briri']
  spec.email                       = 'briley@ucop.edu'
  spec.files                       = ['lib/dmp/response_formatter.rb']
  spec.license                     = 'MIT'
  spec.homepage                    = 'https://github.com/CDLUC3/dmphub-v2/tree/main/gems/dmp-response_formatter'

  spec.metadata['source_code_uri'] = 'https://github.com/CDLUC3/dmphub-v2/tree/main/gems/dmp-response_formatter'

  spec.add_dependency 'json-schema', '~> 3.0'

  spec.add_development_dependency 'rspec', '~> 3.11'
  spec.add_development_dependency 'rubocop', '~> 1.29'
end

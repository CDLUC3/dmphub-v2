# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'dmp/s3_adapter/version'

Gem::Specification.new do |spec|
  spec.required_ruby_version       = '~> 2.7'
  spec.name                        = 'dmp-s3_adapter'
  spec.version                     = Dmp::S3Adapter::VERSION
  spec.summary                     = 'DMP adapter for an AWS S3 Bucket'
  spec.authors                     = ['briri']
  spec.email                       = 'briley@ucop.edu'
  spec.files                       = ['lib/dmp/s3_adapter.rb']
  spec.license                     = 'MIT'
  spec.homepage                    = 'https://github.com/CDLUC3/dmphub-v2/tree/main/gems/dmp-s3_adapter'

  spec.metadata['source_code_uri'] = 'https://github.com/CDLUC3/dmphub-v2/tree/main/gems/dmp-s3_adapter'

  spec.add_dependency 'aws-sdk-s3', '~> 1.114'

  spec.add_development_dependency 'rspec', '~> 3.11'
  spec.add_development_dependency 'rubocop', '~> 1.29'
end

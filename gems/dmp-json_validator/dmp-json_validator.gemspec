Gem::Specification.new do |spec|
  spec.name        = 'dmp-json_validator'
  spec.version     = '0.0.0'
  spec.summary     = "DMP JSON validation for the DMPHub"
  spec.authors     = ["Brian Riley"]
  spec.email       = 'briley@ucop.edu'
  spec.files       = ["lib/dmp-json_validator.rb"]
  spec.homepage    = 'https://github.com/CDLUC3/dmphub-v2/gems/dmp-json_validator'
                     #'https://rubygems.org/gems/hola'
  spec.metadata    = { 
    "source_code_uri" => "https://github.com/example/example" 
    
  }
  spec.license       = 'MIT'
  
  spec.add_runtime_dependency 'json-schema'
end
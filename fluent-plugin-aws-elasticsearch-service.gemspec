# -*- encoding: utf-8 -*-

lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name          = "fluent-plugin-aws-elasticsearch-service"
  spec.version       = "1.2.0"
  spec.authors       = ["atomita"]
  spec.email         = ["sleeping.cait.sith+gh@gmail.com"]

  spec.summary       = %q{Output plugin to post to "Amazon Elasticsearch Service".}
  spec.description   = %q{this is a Output plugin. Post to "Amazon Elasticsearch Service".}
  spec.homepage      = "https://github.com/atomita/fluent-plugin-aws-elasticsearch-service"
  spec.license       = "MIT"


  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.10"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "test-unit", "~> 3.0"
  spec.add_runtime_dependency "fluentd", ">= 0.14"
  spec.add_runtime_dependency "fluent-plugin-elasticsearch", "~> 2.4.0"
  spec.add_runtime_dependency "aws-sdk", "~> 3"
  spec.add_runtime_dependency "faraday_middleware-aws-sigv4", ">= 0.2.4", "< 0.3.0"
end

require 'coverage_helper'

require 'webmock/rspec'
require 'vcr'
require 'rspec-html-matchers'

GEM_ROOT = File.expand_path('../../', __FILE__)
$LOAD_PATH.unshift File.join(GEM_ROOT, 'lib')

# See http://rubydoc.info/gems/rspec-core/RSpec/Core/Configuration
VCR.configure do |c|
  c.cassette_library_dir = 'spec/fixtures/vcr_tests'
  c.hook_into :webmock
  c.ignore_request do |request|
    request.uri =~ /^#{Figaro.env.airbrake_host}/
  end
end

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.order = :random
  Kernel.srand config.seed
end

source "https://rubygems.org"

gem "rdoc", "~> 6.2"
gem "test-unit", "~> 3.0"

group :lint do
  gem "rubocop", "~> 0.80.1"
  gem "rubocop-performance", "~> 1.5.2"
end

gem "webrick", "~> 1.6"
gem "parallel_tests", "~> 2.29"
gem "parallel", "1.19.2" # 1.20+ is required > Ruby 2.3
gem "ronn", "~> 0.7.3", :platform => :ruby
gem "rspec-core", "~> 3.8"
gem "rspec-expectations", "~> 3.8"
gem "rspec-mocks", "~> 3.8"
gem 'uri', "~> 0.10.1"

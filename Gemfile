source 'https://rubygems.org'
git_source(:github) do |repo_name|
  repo_name = "#{repo_name}/#{repo_name}" unless repo_name.include?("/")
  "https://github.com/#{repo_name}.git"
end

# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem 'debug_inspector', '0.0.2'
gem 'mysql2', '~> 0.3.18'
gem 'rails', '~> 4.2.6'
gem 'rake', '~> 11.0'
# Use sqlite3 as the database for Active Record
gem 'sqlite3', '~> 1.3.13'
# Use SCSS for stylesheets
gem 'sass-rails', '~> 5.0'
# Use Uglifier as compressor for JavaScript assets
gem 'uglifier', '>= 1.3.0'
# Use CoffeeScript for .coffee assets and views
gem 'coffee-rails', '~> 4.1.0'
# See https://github.com/rails/execjs#readme for more supported runtimes
gem 'therubyracer', platforms: :ruby

# Use jquery as the JavaScript library
gem 'jquery-rails'
# Turbolinks makes following links in your web application faster. Read more: https://github.com/rails/turbolinks
gem 'turbolinks'
# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
gem 'jbuilder', '~> 2.0'

# Use ActiveModel has_secure_password
# gem 'bcrypt', '~> 3.1.7'

# Use Unicorn as the app server
# gem 'unicorn'

# Use Capistrano for deployment
# gem 'capistrano-rails', group: :development
gem 'capistrano', '~> 2.15'

# for fedora harvester
gem 'rubydora', '~> 1.7.4'
gem 'rdf', '~> 1.1.2'
gem 'rdf-rdfxml'
gem 'figaro'
gem 'deprecation', '~> 0.2.2'
gem 'sentry-raven', '~> 2.7'
gem 'rubocop', '0.40.0'
# Put the next 5 gem requirements to address ruby security vulnerabilities DLTP-1623
gem 'nokogiri', '~> 1.11.4'
gem 'activejob', '~> 4.2.11'
gem 'rack', '~> 1.6.11'
gem 'loofah', '~> 2.2.3'
gem 'yard', '~> 0.9.11'
gem 'sass', '~> 3.4.22'
gem 'scss_lint', '~> 0.38.0'


group :development, :test do
  # Call 'byebug' anywhere in the code to stop execution and get a debugger console
  gem 'byebug'
  gem 'commitment', github: 'ndlib/commitment', ref: 'f7f83ca2f8437c018cd9083cf71ce57788c1c0f6'
  gem 'rspec-rails', '~>3.4.0'
  gem 'rspec-html-matchers', '~>0.6'
  gem 'vcr', require: false
  gem 'webmock', require: false
  gem 'memfs', require: false
end

group :development do
  # Access an IRB console on exception pages or by using <%= console %> in views
  gem 'web-console', '~> 2.0'

  # Spring speeds up development by keeping your application running in the background. Read more: https://github.com/rails/spring
  gem 'spring'
end

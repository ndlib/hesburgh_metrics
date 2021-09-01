# frozen_string_literal: true

# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/capistrano.rake, and they will automatically be available to Rake.

require File.expand_path('config/application', __dir__)

# patch for rake removing `last_comment`. Unsure which remaining gems are using it.
module TempFixForRakeLastComment
  def last_comment
    last_description
  end
end
Rake::Application.include TempFixForRakeLastComment

Rails.application.load_tasks

namespace :db do
  desc 'database management for test & development'
  task prepare: :environment do
    abort('Run this only in test or development') unless Rails.env.test? || Rails.env.development?
    begin
      Rake::Task['db:drop'].invoke
    rescue StandardError
      $stdout.puts 'Unable to drop database, moving on.'
    end
    Rake::Task['db:create'].invoke
    Rake::Task['db:schema:load'].invoke
  end
end

if defined?(RSpec)
  namespace :spec do
    desc 'Run all specs'
    RSpec::Core::RakeTask.new(:all) do
      ENV['COVERAGE'] = 'true'
    end

    namespace :coverage do
      desc 'Run all non-feature specs'
      RSpec::Core::RakeTask.new(:without_features) do |t|
        ENV['COVERAGE'] = 'true'
        t.exclude_pattern = './spec/features/**/*_spec.rb'
        t.rspec_opts = '--profile 10'
      end

      types = begin
        dirs = Dir['./app/**/*.rb'].map do |f|
                 f.sub(%r{^\./(app/\w+)/.*}, '\\1')
               end.uniq.select { |f| File.directory?(f) }
        dirs.index_by { |d| d.split('/').last }
      end

      types.each do |name, _dir|
        desc "Run, with code coverage, the examples in spec/#{name.downcase}"
        RSpec::Core::RakeTask.new(name) do |t|
          ENV['COVERAGE'] = 'true'
          ENV['COV_PROFILE'] = name.downcase
          t.pattern = "./spec/#{name}/**/*_spec.rb"
        end
      end
    end

    desc 'Run the Travis CI specs'
    task travis: :environment do
      ENV['SPEC_OPTS'] ||= '--profile 5'
      Rake::Task[:default].invoke
    end
  end
end

# BEGIN `commitment:install` generator
# This was added via commitment:install generator. You are free to change this.
Rake::Task['default'].clear
task(
  default: [
    'db:prepare',
    'commitment:rubocop',
    'commitment:configure_test_for_code_coverage',
    'spec',
    'commitment:code_coverage',
    'commitment:brakeman'
  ]
)
# END `commitment:install` generator

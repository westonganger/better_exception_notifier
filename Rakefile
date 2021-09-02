require File.expand_path(File.dirname(__FILE__) + '/lib/better_exception_notifier/version.rb')

require "bundler/gem_tasks"
require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/**/*_test.rb"]
end

task default: [:test]

task :console do
  require 'better_exception_notifier'

  require_relative 'test/dummy_app/app/models/post'

  require 'irb'
  binding.irb
end

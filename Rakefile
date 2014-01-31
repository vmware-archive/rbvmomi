require 'rake/testtask'
#require 'rake/rdoctask'
require 'yard'
require "bundler/gem_tasks"

task :default => :test

Rake::TestTask.new do |t|
  t.libs << "test"
  t.test_files = FileList['test/test_*.rb']
  t.verbose = true
end

YARD::Rake::YardocTask.new

#begin
#  require 'rcov/rcovtask'
#  desc 'Measures test coverage using rcov'
#  Rcov::RcovTask.new do |rcov|
#    rcov.pattern    = 'test/test_*.rb'
#    rcov.output_dir = 'coverage'
#    rcov.verbose    = true
#    rcov.libs << "test"
#    rcov.rcov_opts << '--exclude "gems/*"'
#  end
#rescue LoadError
#  puts "Rcov not available. Install it with: gem install rcov"
#end

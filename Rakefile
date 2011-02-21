require 'rake/testtask'
require 'rake/rdoctask'
require 'yard'

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gem|
    gem.name = "rbvmomi"
    gem.summary = "Ruby interface to the VI API"
    #gem.description = ""
    gem.email = "rlane@vmware.com"
    gem.homepage = "https://github.com/rlane/rbvmomi"
    gem.authors = ["Rich Lane"]
    gem.add_dependency 'nokogiri', '>= 1.4.1'
    gem.add_dependency 'builder'
    gem.add_dependency 'trollop'
    gem.add_dependency 'cdb-full'
    gem.required_ruby_version = '>= 1.9.1'
    gem.files.include 'vmodl.cdb'
    gem.files.include '.yardopts'
  end
rescue LoadError
  puts "Jeweler not available. Install it with: gem install jeweler"
end

Rake::TestTask.new do |t|
  t.libs << "test"
  t.test_files = FileList['test/test_*.rb']
  t.verbose = true
end

YARD::Rake::YardocTask.new

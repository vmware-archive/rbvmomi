require 'rake/testtask'
require 'rdoc/task'

begin
  require 'yard'
  YARD::Rake::YardocTask.new
rescue LoadError
  puts "Yard not available. Cannot build documentation. This is most likely not a problem for production use."
  puts "Install Yard with: gem install yard"
end

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gem|
    gem.name = "rbvmomi"
    gem.summary = "Ruby interface to the VMware vSphere API"
    #gem.description = ""
    gem.email = "rlane@vmware.com"
    gem.homepage = "https://github.com/vmware/rbvmomi"
    gem.authors = ["Rich Lane", "Christian Dickmann"]
    gem.add_dependency 'nokogiri', '>= 1.4.1'
    gem.add_dependency 'builder'
    gem.add_dependency 'trollop'
    gem.required_ruby_version = '>= 1.8.7'
    gem.files.include 'vmodl.db'
    gem.files.include '.yardopts'
  end
rescue LoadError
  puts "Jeweler not available. Cannot build gem. This is most likely fatal."
  puts "Install Jeweler with: gem install jeweler"
end

Rake::TestTask.new do |t|
  t.libs << "test"
  t.test_files = FileList['test/test_*.rb']
  t.verbose = true
end

begin
  require 'rcov/rcovtask'
  desc 'Measures test coverage using rcov'
  Rcov::RcovTask.new do |rcov|
    rcov.pattern    = 'test/test_*.rb'
    rcov.output_dir = 'coverage'
    rcov.verbose    = true
    rcov.libs << "test"
    rcov.rcov_opts << '--exclude "gems/*"'
  end
rescue LoadError
  puts "Rcov not available. Cannot build tests. This is most likely not a problem for production use."
  puts "Install Rcov it with: gem install rcov"
end

require 'rake/testtask'
require 'rake/rdoctask'

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
  end
rescue LoadError
  puts "Jeweler not available. Install it with: gem install jeweler"
end

Rake::TestTask.new do |t|
  t.libs << "test"
  t.test_files = FileList['test/test_*.rb']
  t.verbose = true
end

Rake::RDocTask.new do |rd|
  rd.title = "RbVmomi - a Ruby interface to the vSphere API"
  rd.main = "README.rdoc"
  rd.rdoc_files.include("README.rdoc", "lib/rbvmomi/vim.rb", "lib/rbvmomi/vim/*.rb")
  rd.rdoc_dir = "doc"
end

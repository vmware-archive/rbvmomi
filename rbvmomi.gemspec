lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name          = "rbvmomi"
  spec.version       = File.read(File.expand_path(File.join(File.dirname(__FILE__), 'VERSION')))
  spec.summary = "Ruby interface to the VMware vSphere API"
  #spec.description = ""
  spec.email = "rlane@vmware.com"
  spec.homepage = "https://github.com/vmware/rbvmomi"
  spec.authors = ["Rich Lane", "Christian Dickmann"]
  spec.add_dependency 'nokogiri', '>= 1.4.1'
  spec.add_dependency 'builder'
  spec.add_dependency 'trollop'
  spec.required_ruby_version = '>= 1.8.7'
  spec.files << 'vmodl.db'
  spec.files << '.yardopts'

  spec.add_development_dependency "bundler", "~> 1.5"
  spec.add_development_dependency "rake"
end

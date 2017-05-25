# Copyright (c) 2016-2017 VMware, Inc.  All Rights Reserved.
# SPDX-License-Identifier: MIT

$LOAD_PATH.unshift(File.expand_path('../lib', __FILE__))

require 'rbvmomi/version'

Gem::Specification.new do |spec|
  spec.name    = 'rbvmomi'
  spec.summary = 'Ruby interface to the VMware vSphere API'
  spec.version = RbVmomi::VERSION

  spec.authors  = ['Rich Lane', 'Christian Dickmann']
  spec.email    = 'jrg@vmware.com'
  spec.homepage = 'https://github.com/vmware/rbvmomi'
  spec.license  = 'MIT'

  spec.bindir = 'exe'
  spec.files  = `git ls-files -z`.split("\x0").reject { |f| f.match(/^test\//) }
  spec.executables << 'rbvmomish'

  spec.add_runtime_dependency('builder', '~> 3.0')
  spec.add_runtime_dependency('json', '~> 2.1')
  spec.add_runtime_dependency('nokogiri', '~> 1.5')
  spec.add_runtime_dependency('trollop', '~> 2.1')

  spec.add_development_dependency('pry', '~> 0.10.4')
  spec.add_development_dependency('rake', '~> 12.0')
  spec.add_development_dependency('rubocop', '~> 0.48.1')
  spec.add_development_dependency('simplecov', '~> 0.14.1')
  spec.add_development_dependency('yard', '~> 0.9.5')
  spec.add_development_dependency('test-unit', '~> 3.2')

  spec.required_ruby_version = '>= 2.2.0'
end

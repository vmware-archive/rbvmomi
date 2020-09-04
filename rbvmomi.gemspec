# Copyright (c) 2016-2020 VMware, Inc.  All Rights Reserved.
# SPDX-License-Identifier: MIT

$LOAD_PATH.unshift(File.expand_path('lib', __dir__))

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
  spec.files  = %w[LICENSE README.md vmodl.db] + Dir.glob('{lib,exe}/**/*')
  spec.executables << 'rbvmomish'

  spec.add_runtime_dependency('builder', '~> 3.2')
  spec.add_runtime_dependency('json', '~> 2.3')
  spec.add_runtime_dependency('nokogiri', '~> 1.10')
  spec.add_runtime_dependency('optimist', '~> 3.0')

  spec.add_development_dependency('activesupport')
  spec.add_development_dependency('pry', '~> 0.13.1')
  spec.add_development_dependency('rake', '~> 13.0')
  spec.add_development_dependency('simplecov', '~> 0.19.0')
  spec.add_development_dependency('soap4r-ng', '~> 2.0')
  spec.add_development_dependency('test-unit', '~> 3.3')
  spec.add_development_dependency('yard', '~> 0.9.25')

  spec.required_ruby_version = '>= 2.4.1'
end

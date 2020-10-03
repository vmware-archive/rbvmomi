# Copyright (c) 2010-2017 VMware, Inc.  All Rights Reserved.
# SPDX-License-Identifier: MIT

require 'bundler/gem_tasks'
require 'rake/testtask'
require 'yard'
require 'rubocop/rake_task'

task(:default => :test)

Rake::TestTask.new do |t|
  t.libs << "test"
  t.test_files = FileList['test/test_*.rb']
  t.verbose = true
  t.warning = true
end

RuboCop::RakeTask.new

YARD::Rake::YardocTask.new

# Copyright (c) 2011-2017 VMware, Inc.  All Rights Reserved.
# SPDX-License-Identifier: MIT

unless /^1.8/ =~ RUBY_VERSION
  require 'simplecov'
  SimpleCov.start { add_filter '/test/' }
end

require 'rbvmomi'
VIM = RbVmomi::VIM

require 'test/unit'

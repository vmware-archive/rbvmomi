require 'simplecov'
SimpleCov.start { add_filter '/test/' }

require 'rbvmomi'
VIM = RbVmomi::VIM

require 'test/unit'

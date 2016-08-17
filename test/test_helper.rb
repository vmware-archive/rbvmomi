unless /^1.8/ =~ RUBY_VERSION
  require 'simplecov'
  SimpleCov.start { add_filter '/test/' }
end

require 'rbvmomi'
VIM = RbVmomi::VIM

require 'test/unit'

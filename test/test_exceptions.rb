require 'test/unit'
require 'rbvmomi'
include RbVmomi

class ExceptionTest < Test::Unit::TestCase
  def test_fault
    begin
      fault = VIM::InvalidArgument.new invalidProperty: 'foo'
      assert_raises RbVmomi::Fault do
        raise RbVmomi.fault('A specified parameter was not correct.', fault)
      end
    rescue VIM::InvalidArgument
      assert_equal 'foo', $!.invalidProperty
    end
  end
end

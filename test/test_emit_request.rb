require 'test/unit'
require 'rbvmomi'
include RbVmomi

module D

StringArray = [
  {
    'name' => 'blah',
    'is-array' => true,
    'is-optional' => true,
    'wsdl_type' => 'xsd:string',
  }
]

end

class EmitRequestTest < Test::Unit::TestCase
  MO = VIM::VirtualMachine(nil, "foo")

  def check desc, str, this, params
    soap = RbVmomi::Soap.new({})
    xml = Builder::XmlMarkup.new :indent => 2
    soap.emit_request xml, 'root', desc, this, params

    puts "expected:"
    puts str
    puts
    puts "got:"
    puts xml.target!
    puts

    assert_equal str, xml.target!
  end

  def test_string_array
    check D::StringArray, <<-EOS, MO, blah: ['a', 'b', 'c']
<root xmlns="urn:vim25">
  <_this type="VirtualMachine">foo</_this>
  <blah>a</blah>
  <blah>b</blah>
  <blah>c</blah>
</root>
    EOS
  end
end


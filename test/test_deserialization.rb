require 'test/unit'
require 'rbvmomi'
include RbVmomi

class DeserializationTest < Test::Unit::TestCase
  def setup
    @soap = RbVmomi::Soap.new URI.parse("http://localhost/")
  end

  def check str, expected
    expected = { :root => expected }
    got = @soap.xml2obj Nokogiri(str)

    puts "expected:"
    pp expected
    puts
    puts "got:"
    pp got
    puts

    assert_equal expected, got
  end

  def test_moref
    check <<-EOS, @soap.moRef('Folder', 'ha-folder-root')
<root type="Folder">ha-folder-root</root>
    EOS
  end

  def test_primitives
    check <<-EOS, :int => 42, :bool => false, :string => "foo", :string2 => "bar", :arr => [1, "baz"]
<root xmlns:xsi="#{RbVmomi::Soap::NS_XSI}">
  <int xsi:type="xsd:int">42</int>
  <bool xsi:type="xsd:boolean">false</bool>
  <string>foo</string>
  <string2 xsi:type="xsd:string">bar</string2>
  <arr xsi:type="xsd:int">1</arr>
  <arr xsi:type="xsd:string">baz</arr>
</root>
    EOS
  end
end

require 'trivial_soap'
require 'linguistics'
Linguistics.use :en

module RbVmomi

Typed = Struct.new(:type, :value)

class NiceHash < Hash
  def initialize
    super do |h,k|
      if k2 = h.keys.find { |x| x.to_s.en.plural.to_sym == k }
        case v = h[k2]
        when Array then v
        when nil then []
        else [v]
        end
      else
        nil
      end
    end
  end

  def method_missing sym, *args
    if sym.to_s =~ /=$/
      super unless args.size == 1
      self[$`.to_sym] = args.first
    else
      super unless args.empty?
      self[sym]
    end
  end

  def self.[] *a
    new.tap { |h| h.merge! super }
  end
end

def self.type name
  return unless name
  name = name.to_s
  return [type($')] if name =~ /^ArrayOf/

  if name =~ /^xsd:/
    XSD.type $'
  else
    VIM.type name
  end
end

module XSD
  def self.type name
    case name
    when 'anyType'
      nil
    when 'boolean'
      nil
    when "string"
      String
    when "int", "long", "short", "byte"
      Integer
    else fail "no such xsd type #{name.inspect}"
    end
  end

  def self.method_missing sym, arg
    RbVmomi::Typed.new "xsd:#{sym}", arg
  end
end

class Soap < TrivialSoap
  NS_XSI = 'http://www.w3.org/2001/XMLSchema-instance'

  def serviceInstance
    VIM::ServiceInstance self, 'ServiceInstance'
  end

  def propertyCollector
    @propertyCollector ||= serviceInstance.RetrieveServiceContent!.propertyCollector
  end

  def call method, o={}
    resp = request 'urn:vim25/4.0' do |xml|
      fail unless o.is_a? Hash
      xml.tag! method, :xmlns => 'urn:vim25' do
        yield xml if block_given?
        o.each { |k,v| obj2xml xml, k.to_s, nil, v }
      end
    end
    if resp.at('faultcode')
      fail "#{resp.at('faultcode').text}: #{resp.at('faultstring').text}"
    else
      xml2obj(resp).returnval
    end
  end

  def xml2obj xml, type=nil
    type = xml.attribute_with_ns('type', NS_XSI) || type
    if type
      typed_xml2obj xml, type
    else
      untyped_xml2obj xml
    end
  end

  def typed_xml2obj xml, type
    case type.to_s
    when 'xsd:string' then xml.text
    when 'xsd:int', 'xsd:long' then xml.text.to_i
    when 'xsd:boolean' then xml.text == 'true'
    when /^xsd:/ then fail "unexpected xsd type #{type}"
    when 'ManagedObjectReference' then
      VIM.const_get(xml['type']).new(self, xml.text)
    when /^ArrayOf(\w+)$/ then
      etype = $1
      xml.children.select(&:element?).map { |x| xml2obj x, etype }
    when 'ManagedEntityStatus' then xml.text
    else untyped_xml2obj xml
    end
  end

  def untyped_xml2obj xml
    if xml.children.nil?
      nil
    elsif xml.children.size == 1 and
          xml.children.first.text? and
          xml.attributes.keys == %w(type) and
          xml['type'] =~ /^[A-Z]/
      VIM.const_get(xml['type']).new(self, xml.text)
    elsif xml.children.size == 1 && xml.children.first.text?
      xml.text
    else
      NiceHash.new.tap do |hash|
        xml.children.select(&:element?).each do |child|
          key = child.name.to_sym
          current = hash[key] if hash.member? key
          case current
          when Array
            hash[key] << xml2obj(child)
          when nil
            hash[key] = xml2obj(child)
          else
            hash[key] = [current, xml2obj(child)]
          end
        end
      end
    end
  end

  def obj2xml xml, name, type, o, attrs={}
    expected = RbVmomi.type(type)
    case o
    when VIM::ManagedObject
      fail "expected #{expected.wsdl_name}, got #{o.class.wsdl_name} for field #{name.inspect}" if expected and not expected >= o.class
      xml.tag! name, o._ref, :type => o.class.wsdl_name
    when VIM::DataObject
      fail "expected #{expected.wsdl_name}, got #{o.class.wsdl_name} for field #{name.inspect}" if expected and not expected >= o.class
      xml.tag! name, attrs.merge("xsi:type" => o.class.wsdl_name) do
        o.class.full_props_desc.each do |desc|
          k = desc['name'].to_sym
          v = o.props[k] or next
          obj2xml xml, k.to_s, desc['wsdl_type'], v
        end
      end
    when VIM::Enum
      fail "expected #{expected.wsdl_name}, got #{o.class.wsdl_name} for field #{name.inspect}" if expected and not expected == o.class
      obj2xml xml, name, nil, o.value
    when Hash
      fail unless expected
      obj2xml xml, name, type, expected.new(o), attrs
    when Array
      fail "expected array for field #{name.inspect}" unless type =~ /^ArrayOf/
      expected = RbVmomi.type($')
      o.each do |v|
        obj2xml xml, name, expected, v, attrs
      end
    when Symbol, String, Integer, true, false
      xml.tag! name, o.to_s, attrs
    when Typed
      obj2xml xml, name, nil, o.value, 'xsi:type' => o.type.to_s
    else fail "unexpected object class #{o.class}"
    end
    xml
  end
end

def self.connect uri
  uri = case uri
        when String then URI.parse uri
        when URI then uri
        else fail "invalid URI"
        end

  user = uri.user || 'root'
  password = uri.password || ''

  Soap.new(uri).tap do |vim|
    vim.debug = true if ENV['RBVMOMI_DEBUG']
    vim.serviceInstance.RetrieveServiceContent!.sessionManager.Login! :userName => user, :password => password
  end
end

end

require 'rbvmomi/types'
RbVmomi::VIM.load File.join(File.dirname(__FILE__), "../vmodl.yaml")

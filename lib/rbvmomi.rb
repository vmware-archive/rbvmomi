require 'trivial_soap'
require 'time'
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
  elsif %w(String).member? name
    XSD.type name
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
    when "string", "String"
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

  def call method, desc, o
    fail unless o.is_a? Hash
    fail unless desc.is_a? Hash
    resp = request 'urn:vim25/4.0' do |xml|
      xml.tag! method, :xmlns => 'urn:vim25' do
        yield xml if block_given?
        obj2xml xml, '_this', 'ManagedObject', o['_this']
        desc['params'].each do |d|
          k = d['name'].to_sym
          next unless o.member? k
          obj2xml xml, d['name'], d['wsdl_type'], o[k]
        end
      end
    end
    if resp.at('faultcode')
      fail "#{resp.at('faultcode').text}: #{resp.at('faultstring').text}"
    else
      if desc['result']['wsdl_type']
        xml2obj resp.children.first, desc['result']['wsdl_type']
      else
        nil
      end
    end
  end

  def xml2obj xml, type
    type = xml.attribute_with_ns('type', NS_XSI) || type.to_s
    if type =~ /^xsd:/
      xml2obj_xsd xml, $'
    else
      t = RbVmomi.type type
      if t.is_a? Array
        xml.children.select { |c| c.element? }.map do |c|
          xml2obj c, t[0].wsdl_name
        end
      elsif t <= VIM::DataObject
        props_desc = t.full_props_desc
        h = {}
        props_desc.select { |d| d['wsdl_type'] =~ /^ArrayOf/ }.each { |d| h[d['name'].to_sym] = [] }
        xml.children.each do |c|
          next unless c.element?
          field = c.name.to_sym
          d = t.find_prop_desc(field.to_s) or fail("unexpected field #{field.inspect} in #{t}")
          if h[field].is_a? Array
            d['wsdl_type'] =~ /^ArrayOf/ or fail
            h[field] << xml2obj(c,$')
          else
            h[field] = xml2obj(c,d['wsdl_type'])
          end
        end
        t.new h
      elsif t == VIM::ManagedObjectReference
        RbVmomi.type(xml['type']).new self, xml.text
      elsif t <= VIM::ManagedObject
        t.new self, xml.text
      elsif t <= VIM::Enum
        xml.text
      elsif t <= String
        xml.text
      else fail t.inspect
      end
    end
  end

  def xml2obj_xsd xml, type
    case type
    when 'string' then xml.text
    when 'byte', 'short', 'int', 'long' then xml.text.to_i
    when 'boolean' then xml.text == 'true' || xml.text == '1'
    when 'dateTime' then Time.parse xml.text
    when 'anyType' then fail "attempted to deserialize an anyType"
    else fail "unexpected XSD type #{type.inspect}"
    end
  end

  def obj2xml xml, name, type, o, attrs={}
    expected = RbVmomi.type(type)
    fail "expected array for field #{name}" if expected.is_a? Array and not o.is_a? Array
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
        obj2xml xml, name, expected.wsdl_name, v, attrs
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

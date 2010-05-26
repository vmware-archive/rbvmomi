require 'trivial_soap'
require 'time'

module RbVmomi

Boolean = Class.new
AnyType = Class.new

def self.type name
  fail unless name
  name = $' if name.to_s =~ /^xsd:/
  case name.to_sym
  when :anyType then AnyType
  when :boolean then Boolean
  when :string then String
  when :int, :long, :short, :byte then Integer
  when :float, :double then Float
  when :dateTime then Time
  else
    if VIM.has_type? name
      VIM.type name
    else
      fail "no such type #{name.inspect}"
    end
  end
end

class DeserializationFailed < Exception
  attr_accessor :xml

  def extra
    { xml: xml.to_s }
  end
end

def dfail xml, msg
  raise DeserializationFailed.new.tap { |e| e.xml = xml }
end

class Soap < TrivialSoap
  NS_XSI = 'http://www.w3.org/2001/XMLSchema-instance'

  def initialize opts
    @rev = opts[:rev] || '4.1'
    super opts
  end

  def serviceInstance
    VIM::ServiceInstance self, 'ServiceInstance'
  end

  def root
    @rootFolder ||= serviceInstance.content.rootFolder
  end

  def propertyCollector
    @propertyCollector ||= serviceInstance.RetrieveServiceContent.propertyCollector
  end

  def call method, desc, o
    fail unless o.is_a? Hash
    fail unless desc.is_a? Hash
    resp = request "urn:vim25/#{@rev}" do |xml|
      xml.tag! method, :xmlns => 'urn:vim25' do
        yield xml if block_given?
        obj2xml xml, '_this', 'ManagedObject', false, o['_this']
        desc['params'].each do |d|
          k = d['name'].to_sym
          next unless o.member? k
          obj2xml xml, d['name'], d['wsdl_type'], d['is-array'], o[k]
        end
      end
    end
    if resp.at('faultcode')
      fault = xml2obj(resp.at('detail').children.first, 'MethodFault')
      msg = resp.at('faultstring').text
      raise RbVmomi.fault msg, fault
    else
      if rdesc = desc['result']
        type = rdesc['is-task'] ? 'Task' : rdesc['wsdl_type']
        returnvals = resp.children.select(&:element?).map { |c| xml2obj c, type }
        rdesc['is-array'] ? returnvals : returnvals.first
      else
        nil
      end
    end
  end

  def demangle_array_type x
    case x
    when 'AnyType' then 'anyType'
    when 'DateTime' then 'dateTime'
    when 'Boolean', 'String', 'Byte', 'Short', 'Int', 'Long', 'Float', 'Double' then x.downcase
    else x
    end
  end

  def xml2obj xml, type
    type = (xml.attribute_with_ns('type', NS_XSI) || type).to_s

    if type =~ /^ArrayOf/
      type = demangle_array_type $'
      return xml.children.select(&:element?).map { |c| xml2obj c, type }
    end

    t = RbVmomi.type type
    if t <= VIM::DataObject
      #puts "deserializing data object #{t} from #{xml.name}"
      props_desc = t.full_props_desc
      h = {}
      props_desc.select { |d| d['is-array'] }.each { |d| h[d['name'].to_sym] = [] }
      xml.children.each do |c|
        next unless c.element?
        field = c.name.to_sym
        #puts "field #{field.to_s}: #{t.find_prop_desc(field.to_s).inspect}"
        d = t.find_prop_desc(field.to_s) or next
        o = xml2obj c, d['wsdl_type']
        if h[field].is_a? Array
          h[field] << o
        else
          h[field] = o
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
    elsif t <= Symbol
      xml.text.to_sym
    elsif t <= Integer
      xml.text.to_i
    elsif t <= Float
      xml.text.to_f
    elsif t <= Time
      Time.parse xml.text
    elsif t == Boolean
      xml.text == 'true' || xml.text == '1'
    elsif t == AnyType
      fail "attempted to deserialize an AnyType"
    else fail "unexpected type #{t.inspect}"
    end
  end

  def obj2xml xml, name, type, is_array, o, attrs={}
    expected = RbVmomi.type(type)
    fail "expected array, got #{o.class.wsdl_name}" if is_array and not o.is_a? Array
    case o
    when Array
      fail "expected #{expected.wsdl_name}, got array" unless is_array
      o.each do |e|
        obj2xml xml, name, expected.wsdl_name, false, e, attrs
      end
    when VIM::ManagedObject
      fail "expected #{expected.wsdl_name}, got #{o.class.wsdl_name} for field #{name.inspect}" if expected and not expected >= o.class
      xml.tag! name, o._ref, :type => o.class.wsdl_name
    when VIM::DataObject
      fail "expected #{expected.wsdl_name}, got #{o.class.wsdl_name} for field #{name.inspect}" if expected and not expected >= o.class
      xml.tag! name, attrs.merge("xsi:type" => o.class.wsdl_name) do
        o.class.full_props_desc.each do |desc|
          v = o.props[desc['name'].to_sym] or next  # TODO check is-optional
          obj2xml xml, desc['name'], desc['wsdl_type'], desc['is-array'], v
        end
      end
    when VIM::Enum
      xml.tag! name, o.value.to_s, attrs
    when Hash
      fail "expected #{expected.wsdl_name}, got a hash" unless expected <= VIM::DataObject
      obj2xml xml, name, type, false,expected.new(o), attrs
    when true, false
      fail "expected #{expected.wsdl_name}, got a boolean" unless expected == Boolean
      attrs['xsi:type'] = 'xsd:boolean' if expected == AnyType
      xml.tag! name, (o ? '1' : '0'), attrs
    when Symbol, String
      attrs['xsi:type'] = 'xsd:string' if expected == AnyType
      xml.tag! name, o.to_s, attrs
    when Integer
      attrs['xsi:type'] = 'xsd:long' if expected == AnyType
      xml.tag! name, o.to_s, attrs
    when Float
      attrs['xsi:type'] = 'xsd:double' if expected == AnyType
      xml.tag! name, o.to_s, attrs
    else fail "unexpected object class #{o.class}"
    end
    xml
  end
end

class Fault < Exception
end

def self.fault msg, fault
  Fault.new("#{fault.class.wsdl_name}: #{msg}")
end

# host, port, ssl, user, password, path, debug
def self.connect opts
  fail unless opts.is_a? Hash
  fail "host option required" unless opts[:host]
  opts[:user] ||= 'root'
  opts[:password] ||= ''
  opts[:ssl] = true unless opts.member? :ssl
  opts[:port] ||= (opts[:ssl] ? 443 : 80)
  opts[:path] ||= '/sdk'
  opts[:debug] = (!ENV['RBVMOMI_DEBUG'].empty? rescue false) unless opts.member? :debug

  Soap.new(opts).tap do |vim|
    vim.serviceInstance.RetrieveServiceContent.sessionManager.Login :userName => opts[:user], :password => opts[:password]
  end
end

end

require 'rbvmomi/types'
vmodl_fn = ENV['VMODL'] || File.join(File.dirname(__FILE__), "../vmodl")
RbVmomi::VIM.load vmodl_fn

require 'rbvmomi/extensions'

# Copyright (c) 2010 VMware, Inc.  All Rights Reserved.
require 'time'
require 'rbvmomi/trivial_soap'
require 'rbvmomi/basic_types'
require 'rbvmomi/fault'
require 'rbvmomi/type_loader'

module RbVmomi

class DeserializationFailed < Exception; end

class Connection < TrivialSoap
  NS_XSI = 'http://www.w3.org/2001/XMLSchema-instance'

  attr_accessor :rev

  def initialize opts
    @ns = opts[:ns] or fail "no namespace specified"
    @rev = opts[:rev] or fail "no revision specified"
    super opts
  end

  def emit_request xml, method, descs, this, params
    xml.tag! method, :xmlns => @ns do
      obj2xml xml, '_this', 'ManagedObject', false, this
      descs.each do |d|
        k = d['name'].to_sym
        if params.member? k or params.member? k.to_s
          v = params.member?(k) ? params[k] : params[k.to_s]
          obj2xml xml, d['name'], d['wsdl_type'], d['is-array'], v
        else
          fail "missing required parameter #{d['name']}" unless d['is-optional']
        end
      end
    end
  end

  def parse_response resp, desc
    if resp.at('faultcode')
      detail = resp.at('detail')
      fault = detail && xml2obj(detail.children.first, 'MethodFault')
      msg = resp.at('faultstring').text
      if fault
        raise RbVmomi::Fault.new(msg, fault)
      else
        fail "#{resp.at('faultcode').text}: #{msg}"
      end
    else
      if desc
        type = desc['is-task'] ? 'Task' : desc['wsdl_type']
        returnvals = resp.children.select(&:element?).map { |c| xml2obj c, type }
        (desc['is-array'] && !desc['is-task']) ? returnvals : returnvals.first
      else
        nil
      end
    end
  end

  def call method, desc, this, params
    fail "this is not a managed object" unless this.is_a? BasicTypes::ManagedObject
    fail "parameters must be passed as a hash" unless params.is_a? Hash
    fail unless desc.is_a? Hash

    resp = request "#{@ns}/#{@rev}" do |xml|
      emit_request xml, method, desc['params'], this, params
    end

    parse_response resp, desc['result']
  end

  def demangle_array_type x
    case x
    when 'AnyType' then 'anyType'
    when 'DateTime' then 'dateTime'
    when 'Boolean', 'String', 'Byte', 'Short', 'Int', 'Long', 'Float', 'Double' then x.downcase
    else x
    end
  end

  def xml2obj xml, typename
    typename = (xml.attribute_with_ns('type', NS_XSI) || typename).to_s

    if typename =~ /^ArrayOf/
      typename = demangle_array_type $'
      return xml.children.select(&:element?).map { |c| xml2obj c, typename }
    end

    t = type typename
    if t <= BasicTypes::DataObject
      props_desc = t.full_props_desc
      h = {}
      props_desc.select { |d| d['is-array'] }.each { |d| h[d['name'].to_sym] = [] }
      xml.children.each do |c|
        next unless c.element?
        field = c.name.to_sym
        d = t.find_prop_desc(field.to_s) or next
        o = xml2obj c, d['wsdl_type']
        if h[field].is_a? Array
          h[field] << o
        else
          h[field] = o
        end
      end
      t.new h
    elsif t == BasicTypes::ManagedObjectReference
      type(xml['type']).new self, xml.text
    elsif t <= BasicTypes::ManagedObject
      type(xml['type'] || t.wsdl_name).new self, xml.text
    elsif t <= BasicTypes::Enum
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
    elsif t == BasicTypes::Boolean
      xml.text == 'true' || xml.text == '1'
    elsif t == BasicTypes::Binary
      xml.text.unpack('m')[0]
    elsif t == BasicTypes::AnyType
      fail "attempted to deserialize an AnyType"
    else fail "unexpected type #{t.inspect}"
    end
  end

  # hic sunt dracones
  def obj2xml xml, name, type, is_array, o, attrs={}
    expected = type(type)
    fail "expected array, got #{o.class.wsdl_name}" if is_array and not o.is_a? Array
    case o
    when Array
      fail "expected #{expected.wsdl_name}, got array" unless is_array
      o.each do |e|
        obj2xml xml, name, expected.wsdl_name, false, e, attrs
      end
    when BasicTypes::ManagedObject
      fail "expected #{expected.wsdl_name}, got #{o.class.wsdl_name} for field #{name.inspect}" if expected and not expected >= o.class
      xml.tag! name, o._ref, :type => o.class.wsdl_name
    when BasicTypes::DataObject
      fail "expected #{expected.wsdl_name}, got #{o.class.wsdl_name} for field #{name.inspect}" if expected and not expected >= o.class
      xml.tag! name, attrs.merge("xsi:type" => o.class.wsdl_name) do
        o.class.full_props_desc.each do |desc|
          if o.props.member? desc['name'].to_sym
            v = o.props[desc['name'].to_sym]
            next if v.nil?
            obj2xml xml, desc['name'], desc['wsdl_type'], desc['is-array'], v
          end
        end
      end
    when BasicTypes::Enum
      xml.tag! name, o.value.to_s, attrs
    when Hash
      fail "expected #{expected.wsdl_name}, got a hash" unless expected <= BasicTypes::DataObject
      obj2xml xml, name, type, false, expected.new(o), attrs
    when true, false
      fail "expected #{expected.wsdl_name}, got a boolean" unless expected == BasicTypes::Boolean
      attrs['xsi:type'] = 'xsd:boolean' if expected == BasicTypes::AnyType
      xml.tag! name, (o ? '1' : '0'), attrs
    when Symbol, String
      if expected == BasicTypes::Binary
        attrs['xsi:type'] = 'xsd:base64Binary' if expected == BasicTypes::AnyType
        xml.tag! name, [o].pack('m').chomp, attrs
      else
        attrs['xsi:type'] = 'xsd:string' if expected == BasicTypes::AnyType
        xml.tag! name, o.to_s, attrs
      end
    when Integer
      attrs['xsi:type'] = 'xsd:long' if expected == BasicTypes::AnyType
      xml.tag! name, o.to_s, attrs
    when Float
      attrs['xsi:type'] = 'xsd:double' if expected == BasicTypes::AnyType
      xml.tag! name, o.to_s, attrs
    when DateTime
      attrs['xsi:type'] = 'xsd:dateTime' if expected == BasicTypes::AnyType
      xml.tag! name, o.to_s, attrs
    else fail "unexpected object class #{o.class}"
    end
    xml
  end

  def self.type name
    fail unless name and (name.is_a? String or name.is_a? Symbol)
    name = $' if name.to_s =~ /^xsd:/
    case name.to_sym
    when :anyType then BasicTypes::AnyType
    when :boolean then BasicTypes::Boolean
    when :string then String
    when :int, :long, :short, :byte then Integer
    when :float, :double then Float
    when :dateTime then Time
    when :base64Binary then BasicTypes::Binary
    else
      if @loader.has_type? name
        const_get(name)
      else
        fail "no such type #{name.inspect}"
      end
    end
  end

  def type name
    self.class.type name
  end

  def self.extension_path
    fail "must be implemented in subclass"
  end

  def self.loader; @loader; end

protected

  def self.const_missing sym
    name = sym.to_s
    if @loader and @loader.has_type? name
      @loader.load_type name
      const_get sym
    else
      super
    end
  end

  def self.method_missing sym, *a
    if @loader and @loader.has_type? sym.to_s
      const_get(sym).new(*a)
    else
      super
    end
  end

  def self.load_vmodl fn
    @loader = RbVmomi::TypeLoader.new self, fn
    @loader.init
  end
end

end

# Copyright (c) 2011 VMware, Inc.  All Rights Reserved.
require 'time'

module RbVmomi

class NewDeserializer
  NS_XSI = 'http://www.w3.org/2001/XMLSchema-instance'

  DEMANGLED_ARRAY_TYPES = {
    'AnyType' => 'xsd:anyType',
    'DateTime' => 'xsd:dateTime',
  }
  %w(Boolean String Byte Short Int Long Float Double).each do |x|
    DEMANGLED_ARRAY_TYPES[x] = "xsd:#{x.downcase}"
  end

  BUILTIN = Set.new %w(
    xsd:string xsd:boolean xsd:int xsd:long xsd:float xsd:dateTime xsd:base64Binary
    KeyValue PropertyPath
  )

  def initialize conn
    @conn = conn
    @loader = conn.class.loader
  end

  def deserialize node, type=nil
    type_attr = node['type']
    type = type_attr if type_attr

    if BUILTIN.member? type
      case type
      when 'xsd:string', 'PropertyPath' then node.content
      when 'xsd:boolean' then node.content == '1'
      when 'xsd:int', 'xsd:long' then node.content.to_i
      when 'xsd:float' then node.content.to_f
      when 'xsd:dateTime' then leaf_date node
      when 'xsd:base64Binary' then leaf_binary node
      when 'KeyValue' then leaf_keyvalue node
      else fail
      end
    else
      if type =~ /^ArrayOf/
        type = DEMANGLED_ARRAY_TYPES[$'] || $'
        return node.children.select(&:element?).map { |c| deserialize c, type }
      end

      klass = @loader.get(type) or fail "no such type #{type}"
      if klass < VIM::DataObject then traverse_data node, klass
      elsif klass < RbVmomi::BasicTypes::Enum then node.content
      elsif klass < VIM::ManagedObject then traverse_managed node, klass
      else fail "unexpected class #{klass}"
      end
    end
  end

  def traverse_data node, klass
    obj = klass.new nil
    props = obj.props

    # XXX cleanup
    props_desc = klass.full_props_desc
    props_desc.select { |d| d['is-array'] }.each { |d| props[d['name'].to_sym] = [] }

    node.children.each do |child|
      next unless child.element?
      child_name = child.name
      child_desc = klass.find_prop_desc child_name
      fail "no such property #{child_name} in #{type}" unless child_desc
      child_type = child_desc['wsdl_type']
      o = deserialize child, child_type
      k = child_name.to_sym
      if props[k].is_a? Array
        props[k] << o
      else
        props[k] = o
      end
    end
    obj
  end

  def traverse_managed node, klass
    type_attr = node['type']
    klass = @loader.get(type_attr) if type_attr
    klass.new(@conn, node.content)
  end

  def leaf_date node
    Time.parse node.content
  end

  def leaf_binary node
    node.content.unpack('m')[0]
  end

  # XXX does the value need to be deserialized?
  def leaf_keyvalue node
    h = {}
    node.children.each do |child|
      next unless child.element?
      h[child.name] = child.content
    end
    [h['key'], h['value']]
  end 
end

class OldDeserializer
  NS_XSI = 'http://www.w3.org/2001/XMLSchema-instance'

  def initialize conn
    @conn = conn
  end

  def deserialize xml, typename=nil
    if IS_JRUBY
      type_attr = xml.attribute_nodes.find { |a| a.name == 'type' &&
                                                 a.namespace &&
                                                 a.namespace.prefix == 'xsi' }
    else
      type_attr = xml.attribute_with_ns('type', NS_XSI)
    end
    typename = (type_attr || typename).to_s

    if typename =~ /^ArrayOf/
      typename = demangle_array_type $'
      return xml.children.select(&:element?).map { |c| deserialize c, typename }
    end

    t = @conn.type typename
    if t <= BasicTypes::DataObject
      props_desc = t.full_props_desc
      h = {}
      props_desc.select { |d| d['is-array'] }.each { |d| h[d['name'].to_sym] = [] }
      xml.children.each do |c|
        next unless c.element?
        field = c.name.to_sym
        d = t.find_prop_desc(field.to_s) or next
        o = deserialize c, d['wsdl_type']
        if h[field].is_a? Array
          h[field] << o
        else
          h[field] = o
        end
      end
      t.new h
    elsif t == BasicTypes::ManagedObjectReference
      @conn.type(xml['type']).new self, xml.text
    elsif t <= BasicTypes::ManagedObject
      @conn.type(xml['type'] || t.wsdl_name).new self, xml.text
    elsif t <= BasicTypes::Enum
      xml.text
    elsif t <= BasicTypes::KeyValue
      h = {}
      xml.children.each do |c|
        next unless c.element?
        h[c.name] = c.text
      end
      [h['key'], h['value']]
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
    else fail "unexpected type #{t.inspect} (#{t.ancestors * '/'})"
    end
  rescue
    $stderr.puts "#{$!.class} while deserializing #{xml.name} (#{typename}):"
    $stderr.puts xml.to_s
    raise
  end

  def demangle_array_type x
    case x
    when 'AnyType' then 'anyType'
    when 'DateTime' then 'dateTime'
    when 'Boolean', 'String', 'Byte', 'Short', 'Int', 'Long', 'Float', 'Double' then x.downcase
    else x
    end
  end
end

if ENV['RBVMOMI_NEW_DESERIALIZER'] == '1'
  Deserializer = NewDeserializer
else
  Deserializer = OldDeserializer
end

end

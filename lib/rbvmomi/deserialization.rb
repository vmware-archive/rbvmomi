# Copyright (c) 2011 VMware, Inc.  All Rights Reserved.
require 'time'

module RbVmomi

class Deserializer
  NS_XSI = 'http://www.w3.org/2001/XMLSchema-instance'

  def initialize loader
    @loader = loader
    @vmodl = loader.instance_variable_get :@db
    @property_cache = {}
  end

  def deserialize node, type=nil
    xsi_type_attr = node.attribute_with_ns('type', NS_XSI)
    fail "no type given or in attribute" unless type or xsi_type_attr
    type = xsi_type_attr.value if xsi_type_attr
    case type
    when 'xsd:string' then leaf_string node
    when 'xsd:boolean' then leaf_boolean node
    when 'xsd:int', 'xsd:long' then leaf_int node
    when 'xsd:dateTime' then leaf_date node
    else
      desc = @vmodl[type] or fail "no such type #{type}"
      case desc['kind']
      when 'data' then traverse_data node, type, desc
      when 'managed' then traverse_managed node, type
      else fail "unexpected kind #{desc['kind']}"
      end
    end
  end

  def traverse_data node, type, desc
    klass = @loader.get(type)
    obj = klass.new nil
    props = obj.props
    node.children.each do |child|
      next unless child.element?
      child_name = child.name
      child_desc = find_property(type, child_name)
      fail "no such property #{child_name} in #{type}" unless child_desc
      child_type = child_desc['wsdl_type']
      props[child_name] = deserialize child, child_type
    end
    obj
  end

  def traverse_managed node, type
    klass = @loader.get(type)
    klass.new(nil, node.text)
  end

  def find_property type, name
    @property_cache[[type, name]] ||= find_property_uncached(type, name)
  end

  def find_property_uncached type, name
    while type != 'DataObject'
      desc = @vmodl[type] or fail "no such type #{type}"
      prop_desc = desc['props'].find { |x| x['name'] == name }
      return prop_desc if prop_desc
      type = desc['wsdl_base']
    end
    nil
  end

  def leaf_string node
    node.text
  end

  def leaf_boolean node
    node.text == '1'
  end

  def leaf_int node
    node.text.to_i
  end

  def leaf_date node
    Time.now
  end
end

end

# Copyright (c) 2011 VMware, Inc.  All Rights Reserved.
require 'time'

module RbVmomi

class Deserializer
  NS_XSI = 'http://www.w3.org/2001/XMLSchema-instance'

  def initialize conn
    @conn = conn
    @loader = conn.class.loader
  end

  def deserialize node, type=nil
    type_attr = node['type']
    type = type_attr if type_attr
    case type
    when 'xsd:string' then leaf_string node
    when 'xsd:boolean' then leaf_boolean node
    when 'xsd:int', 'xsd:long' then leaf_int node
    when 'xsd:dateTime' then leaf_date node
    else
      klass = @loader.get(type) or fail "no such type #{type}"
      if klass < VIM::DataObject then traverse_data node, klass
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

  def leaf_string node
    node.content
  end

  def leaf_boolean node
    node.content == '1'
  end

  def leaf_int node
    node.content.to_i
  end

  def leaf_date node
    Time.now
  end
end

end

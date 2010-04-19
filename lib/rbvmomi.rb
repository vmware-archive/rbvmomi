require 'trivial_soap'
#require 'nokogiri_pretty'

module RbVmomi

class Soap < TrivialSoap

  def call method, o={}
    resp = request 'urn:vim25/4.0' do |xml|
      fail unless o.is_a? Hash
      xml.tag! method, :xmlns => 'urn:vim25' do
        yield xml if block_given?
        o.each { |k,v| obj2xml xml, k.to_s, v }
      end
    end
    xml2obj(resp)['returnval']
  end

  def xml2obj xml
    this_node = {}

    xml.children.select(&:element?).each do |child|
      if child.children.nil?
        key, value = child.name, nil
      elsif child.children.size == 1 && child.children.first.text? and child.attributes.keys == %w(type)
        key, value = child.name, MoRef.new(self, child['type'], child.children.first.text)
      elsif child.children.size == 1 && child.children.first.text?
        key, value = child.name, child.children.first.text
      else
        key, value = child.name, xml2obj(child)
      end

      current = this_node[key]
      case current
      when Array
        this_node[key] << value
      when nil
        this_node[key] = value
      else
        this_node[key] = [current.dup, value]
      end
    end

    this_node
  end


  def obj2xml xml, name, o
    case o
    when Hash
      xml.tag! name do
        o.each do |k,v|
          obj2xml xml, k.to_s, v
        end
      end
    when String, Integer, true, false
      xml.tag! name, o.to_s
    when MoRef
      xml.tag! name, o.value, :type => o.type
    else fail "unexpected object class #{o.class}"
    end
    xml
  end
end

class MoRef
  attr_reader :soap, :type, :value

  def initialize soap, type, value
    @soap = soap
    @type = type
    @value = value
  end

  def call method, o={}
    fail unless o.is_a? Hash
    @soap.call method, {'_this' => self}.merge(o)
  end

  def method_missing sym, *args, &b
    call sym, *args, &b
  end

  def pretty_print pp
    pp.text "MoRef(#{type}, #{value})"
  end
end

end

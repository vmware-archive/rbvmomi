require 'trivial_soap'
#require 'nokogiri_pretty'
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

module VIM
  def self.method_missing sym, arg
    RbVmomi::Typed.new sym.to_s, arg
  end
end

module XSD
  def self.method_missing sym, arg
    RbVmomi::Typed.new "xsd:#{sym}", arg
  end
end

class Soap < TrivialSoap
  NS_XSI = 'http://www.w3.org/2001/XMLSchema-instance'

  def serviceInstance
    moRef 'ServiceInstance', 'ServiceInstance'
  end

  def propertyCollector
    @propertyCollector ||= serviceInstance.RetrieveServiceContent!.propertyCollector
  end

  def moRef type, value
    MoRef.new self, type, value
  end

  def call method, o={}
    resp = request 'urn:vim25/4.0' do |xml|
      fail unless o.is_a? Hash
      xml.tag! method, :xmlns => 'urn:vim25' do
        yield xml if block_given?
        o.each { |k,v| obj2xml xml, k.to_s, v }
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
    when 'xsd:int' then xml.text.to_i
    when 'xsd:boolean' then xml.text == 'true'
    when /^xsd:/ then fail "unexpected xsd type #{type}"
    when 'ManagedObjectReference' then MoRef.new(self, xml['type'], xml.text)
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
      MoRef.new(self, xml['type'], xml.text)
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

  def obj2xml xml, name, o, attrs={}
    case o
    when Hash
      xml.tag! name, attrs do
        o.each do |k,v|
          obj2xml xml, k.to_s, v
        end
      end
    when Array
      o.each do |v|
        obj2xml xml, name, v, attrs
      end
    when Symbol, String, Integer, true, false
      xml.tag! name, o.to_s, attrs
    when Typed
      obj2xml xml, name, o.value, 'xsi:type' => o.type.to_s
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
    @properties = nil
  end

  def call method, o={}
    fail unless o.is_a? Hash
    @soap.call method, {'_this' => self}.merge(o)
  end

  def method_missing sym, *args, &b
    if sym.to_s =~ /!$/
      call $`.to_sym, *args, &b
    else
      properties[sym]
    end
  end

  def to_s
    "MoRef(#{type}, #{value})"
  end

  def pretty_print pp
    pp.text to_s
  end

  def properties
    return @properties if @properties
    props = @soap.propertyCollector.RetrieveProperties! :specSet => {
      :propSet => { :type => @type, :all => true },
      :objectSet => { :obj => self },
    }
    @properties = NiceHash[props[:propSet].map { |h| [h[:name].to_sym, h[:val]] }]
  end

  def wait
    filter = @soap.propertyCollector.CreateFilter! :spec => {
      :propSet => { :type => @type, :all => true },
      :objectSet => { :obj => self },
    }, :partialUpdates => false
    result = @soap.propertyCollector.WaitForUpdates!
    filter.DestroyPropertyFilter!
    changes = result.filterSets[0].objectSets[0].changeSets
    NiceHash[changes.map { |h| [h[:name].to_sym, h[:val]] }]
  end

  def wait_until &b
    loop do
      props = wait
      return props if b.call props
    end
  end

  def wait_task
    props = wait_until { |x| %w(success error).member? x[:info][:state] }
    pp props
    case props[:info][:state]
    when 'success'
      info.result
    when 'error'
      fail "task #{info[:key]} failed"
    end
  end

  def [] k
    properties[k]
  end

  def == x
    super unless x.is_a? self.class
    x.type == type and x.value == value
  end

  def hash
    [type, value].hash
  end
end

end

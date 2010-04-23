require 'nokogiri'
require 'set'
require 'pp'
require 'yaml'
require 'dataobject_types'

# removes line breaks and whitespace between xml nodes.
def prepare_xml(xml)
	xml = xml.gsub(/\n+/, "")
	xml = xml.gsub(/(>)\s*(<)/, '\1\2')
end

def analyze_schema schema
	fail unless schema.attributes.keys.sort == %w(elementFormDefault targetNamespace)
	ret = {}
	schema.children.each do |t|
		next if t['name'] == 'ManagedObjectReference'
		case t.name
		when 'simpleType'
			fail if ret.member? t['name']
			ret['vim25:' + t['name']] = analyze_simple_type t
		when 'complexType'
			fail if ret.member? t['name']
			ret['vim25:' + t['name']] = analyze_complex_type t
		when 'include'
		else fail
		end
	end
	ret
end

def analyze_simple_type t
	fail unless t.attributes.keys.sort == %w(name)
	fail unless t.text.empty?
	fail unless t.children.size == 1
	c = t.children.first
	fail unless c.name == 'restriction'
	analyze_restriction c
end

def analyze_restriction x
	fail unless x.attributes.keys.sort == %w(base)
	fail unless x.text.empty?
	values = x.children.map do |c|
		fail unless c.name == 'enumeration'
		fail unless c.attributes.keys.sort == %w(value)
		fail unless c.text.empty?
		fail unless c.children.empty?
		c['value']
	end
	XSDTypes::Enum.new x['base'], values
end

def analyze_complex_type t
	fail unless t.attributes.keys.sort == %w(name)
	fail unless t.text.empty?
	fail unless t.children.size == 1
	child = t.children.first
	case child.name
	when 'sequence'
		XSDTypes::Complex.new nil, analyze_sequence(child)
	when 'complexContent'
		analyze_complex_content child
	else fail
	end
end

def analyze_complex_content x
	fail unless x.attributes.empty?
	fail unless x.text.empty?
	fail unless x.children.size == 1
	c = x.children.first
	fail unless c.name == 'extension'
	h = analyze_complex_extension c
	XSDTypes::Complex.new h[:base], h[:elements]
end

def analyze_complex_extension x
	fail unless x.text.empty?
	fail unless x.attributes.keys.sort == %w(base)
	fail unless x.children.size == 1
	ret = { :base => x.attributes['base'].to_s, :elements => nil }
	c = x.children.first
	fail unless c.name == 'sequence'
	ret[:elements] = analyze_sequence c
	ret
end

def analyze_sequence x
	fail unless x.attributes.empty?
	fail unless x.text.empty?
	ret = {}
	x.children.each do |c|
		fail unless c.name == 'element'
		fail if ret.member? c['name']
		fail unless [%w(name type), %w(minOccurs name type), %w(maxOccurs name type), %w(maxOccurs minOccurs name type)].any? { |y| c.attributes.keys.sort == y }
		fail unless c.text.empty?
		fail unless c.children.empty?
		ret[c['name']] = c['type'].to_s
	end
	ret
end

schemas = []
ARGV.each do |fn|
	nk = Nokogiri(prepare_xml(File.read fn))
	schemas << analyze_schema(nk.at('schema'))
end

=begin
schemas.each do |schema|
	schema.each do |k,v|
		case v
		when XSDTypes::Enum
			next
			puts "#{k}: enum<#{v.base}(#{v.values * ','})"
		when XSDTypes::Simple
			puts "#{k}: simple<#{v.base} #{v.name} : #{v.type}"
		when XSDTypes::Complex
			puts "#{k}: complex<#{v.base}"
			v.elements.each { |ek,ev| puts "  #{ek} : #{ev}" }
		else fail
		end
	end
end
=end

schema = {}.tap { |h| schemas.each { |s| h.merge! s } }
puts YAML.dump(schema)

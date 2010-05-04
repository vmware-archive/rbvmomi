require 'nokogiri'
require 'set'
require 'pp'
require 'yaml'

# removes line breaks and whitespace between xml nodes.
def prepare_xml(xml)
	xml = xml.gsub(/\n+/, "")
	xml = xml.gsub(/(>)\s*(<)/, '\1\2')
end

nk = Nokogiri(prepare_xml(ARGF.read))

messages = Hash.new { |h,k| fail k }
nk.root.children.select { |x| x.name == 'message' }.each do |c|
	fail if messages.member? c.name
	part = c.at('part')
	messages['vim25:' + c['name']] = case part['name']
	when 'parameters', 'fault' then part['element']
	else fail part['name']
	end
end

operations = {}
nk.root.at('portType').children.each do |c|
	fail if operations.member? c['name']
	operations[c['name']] = {
		input: messages[c.at('input')['message']],
		output: messages[c.at('output')['message']],
		faults: Hash[c.children.select { |f| f.name == 'fault' }.map { |f| [f['name'], messages[f['message']]] }]
	}
end
puts YAML.dump(operations)

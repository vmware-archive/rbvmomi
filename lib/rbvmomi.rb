require 'trivial_soap'
require 'nokogiri_pretty'

module RbVmomi

class Soap < TrivialSoap
  def call method, &b
    request 'urn:vim25/4.0' do |xml|
      xml.send method, :xmlns => 'urn:vim25', &b
    end
  end
end

class MoRef
  attr_reader :soap, :type, :value

  def initialize soap, type, value
    @soap = soap
    @type = type
    @value = value
  end

  def call method, &b
    @soap.call method do |xml|
      emit_xml xml, '_this'
      b.call xml if b
    end
  end

  def emit_xml xml, name
    xml.tag! name, value, :type => type
  end
end

end

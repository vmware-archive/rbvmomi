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

end

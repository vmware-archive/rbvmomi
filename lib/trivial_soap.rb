require 'rubygems'
require 'builder'
require 'nokogiri'
require 'net/http'
require 'net/https'
require 'pp'
require 'rbvmomi/profile'

class TrivialSoap
  attr_accessor :debug

  def initialize uri
    raise ArgumentError, "Endpoint URI must be valid" unless uri.scheme
    @uri = uri
    @http = Net::HTTP.new(uri.host, uri.port)
    if @uri.scheme == 'https'
      @http.use_ssl = true
      @http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    end
    @http.set_debug_output(STDERR) if $DEBUG
    @http.read_timeout = 5
    @debug = false
    @cookie = nil
  end

  def soap_envelope
    xsd = 'http://www.w3.org/2001/XMLSchema'
    env = 'http://schemas.xmlsoap.org/soap/envelope/'
    xsi = 'http://www.w3.org/2001/XMLSchema-instance'
    xml = Builder::XmlMarkup.new :indent => 0
    xml.env(:Envelope, 'xmlns:xsd' => xsd, 'xmlns:env' => env, 'xmlns:xsi' => xsi) do
      xml.env(:Body) do
        yield xml if block_given?
      end
    end
    xml
  end

  def request action, &b
    headers = { 'content-type' => 'text/xml; charset=utf-8', 'SOAPAction' => action }
    headers['cookie'] = @cookie if @cookie
    body = soap_envelope(&b).target!
    
    if @debug
      puts "Request:"
      puts body
      puts
    end

    response = profile(:post) { @http.request_post(@uri.path, body, headers) }
    @cookie = response['set-cookie'] if response.key? 'set-cookie'

    nk = Nokogiri(response.body)

    if @debug
      puts "Response"
      puts nk
      puts
    end

    nk.xpath('//soapenv:Body/*').select(&:element?).first
  end
end

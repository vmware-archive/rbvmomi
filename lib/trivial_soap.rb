require 'rubygems'
require 'builder'
require 'nokogiri'
require 'net/http'
require 'pp'
require 'rbvmomi/profile'

class TrivialSoap
  attr_accessor :debug

  def initialize opts
    fail unless opts.is_a? Hash
    @opts = opts
    @http = Net::HTTP.new(@opts[:host], @opts[:port])
    if @opts[:ssl]
      require 'net/https'
      @http.use_ssl = true
      @http.verify_mode = OpenSSL::SSL::VERIFY_NONE # XXX
    end
    @http.set_debug_output(STDERR) if $DEBUG
    @http.read_timeout = 60
    @http.open_timeout = 5
    @debug = @opts[:debug]
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

    response = profile(:post) { @http.request_post(@opts[:path], body, headers) }
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

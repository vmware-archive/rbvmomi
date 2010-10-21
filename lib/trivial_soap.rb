# Copyright (c) 2010 VMware, Inc.  All Rights Reserved.
require 'rubygems'
require 'builder'
require 'nokogiri'
require 'net/http'
require 'pp'
require 'rbvmomi/profile'

class Net::HTTPGenericRequest
  alias old_exec exec

  def exec sock, ver, path
    old_exec sock, ver, path
    sock.io.flush
  end
end

class TrivialSoap
  attr_accessor :debug, :cookie
  attr_reader :http

  def initialize opts
    fail unless opts.is_a? Hash
    @opts = opts
    return unless @opts[:host] # for testcases
    @http = Net::HTTP.new(@opts[:host], @opts[:port], @opts[:proxyHost], @opts[:proxyPort])
    if @opts[:ssl]
      require 'net/https'
      @http.use_ssl = true
      @http.verify_mode = OpenSSL::SSL::VERIFY_NONE # XXX
      @http.cert = OpenSSL::X509::Certificate.new(@opts[:cert]) if @opts[:cert]
      @http.key = OpenSSL::PKey::RSA.new(@opts[:key]) if @opts[:key]
    end
    @http.set_debug_output(STDERR) if $DEBUG
    @http.read_timeout = 60
    @http.open_timeout = 5
    @http.start
    @debug = @opts[:debug]
    @cookie = nil
    @lock = Mutex.new
  end

  def soap_envelope
    xsd = 'http://www.w3.org/2001/XMLSchema'
    env = 'http://schemas.xmlsoap.org/soap/envelope/'
    xsi = 'http://www.w3.org/2001/XMLSchema-instance'
    xml = Builder::XmlMarkup.new :indent => 0
    xml.tag!('env:Envelope', 'xmlns:xsd' => xsd, 'xmlns:env' => env, 'xmlns:xsi' => xsi) do
      xml.tag!('env:Body') do
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
      $stderr.puts "Request:"
      $stderr.puts body
      $stderr.puts
    end

    start_time = Time.now
    response = @lock.synchronize { profile(:post) { @http.request_post(@opts[:path], body, headers) } }
    end_time = Time.now

    @cookie = response['set-cookie'] if response.key? 'set-cookie'

    nk = Nokogiri(response.body)

    if @debug
      $stderr.puts "Response (in #{'%.3f' % (end_time - start_time)} s)"
      $stderr.puts nk
      $stderr.puts
    end

    nk.xpath('//soapenv:Body/*').select(&:element?).first
  end
end

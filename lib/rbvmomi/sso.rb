require 'base64'
require 'net/https'
require 'nokogiri'
require 'openssl'
require 'securerandom'
require 'time'

module RbVmomi
  # Provides access to vCenter Single Sign-On
  class SSO
    BST_PROFILE = 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-x509-token-profile-1.0#X509v3'.freeze
    C14N_CLASS = Nokogiri::XML::XML_C14N_EXCLUSIVE_1_0
    C14N_METHOD = 'http://www.w3.org/2001/10/xml-exc-c14n#'.freeze
    DIGEST_METHOD = 'http://www.w3.org/2001/04/xmlenc#sha512'.freeze
    ENCODING_METHOD = 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-soap-message-security-1.0#Base64Binary'.freeze
    SIGNATURE_METHOD = 'http://www.w3.org/2001/04/xmldsig-more#rsa-sha512'.freeze
    STS_PATH = '/sts/STSService'.freeze
    TOKEN_TYPE = 'urn:oasis:names:tc:SAML:2.0:assertion'.freeze
    TOKEN_PROFILE = 'http://docs.oasis-open.org/wss/oasis-wss-saml-token-profile-1.1#SAMLV2.0'.freeze
    NAMESPACES = {
      :ds => 'http://www.w3.org/2000/09/xmldsig#',
      :soap => 'http://schemas.xmlsoap.org/soap/envelope/',
      :wsse => 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd',
      :wsse11 => 'http://docs.oasis-open.org/wss/oasis-wss-wssecurity-secext-1.1.xsd',
      :wst => 'http://docs.oasis-open.org/ws-sx/ws-trust/200512',
      :wsu => 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd'
    }.freeze

    attr_reader :assertion,
                :assertion_id,
                :certificate,
                :host,
                :user,
                :password,
                :path,
                :port,
                :private_key

    # Creates an instance of an SSO object
    #
    # @param [Hash] opts the options to create the object with
    # @option opts [String] :host the host to connect to
    # @option opts [Fixnum] :port (443) the port to connect to
    # @option opts [String] :path the path to call
    # @option opts [String] :user the user to authenticate with
    # @option opts [String] :password the password to authenticate with
    # @option opts [String] :private_key the private key to use
    # @option opts [String] :certificate the certificate to use
    # @option opts [Boolean] :insecure (false) whether to connect insecurely
    def initialize(opts = {})
      @host     = opts[:host]
      @insecure = opts.fetch(:insecure, false)
      @password = opts[:password]
      @path     = opts.fetch(:path, STS_PATH)
      @port     = opts.fetch(:port, 443)
      @user     = opts[:user]

      load_x509(opts[:private_key], opts[:certificate])
    end

    def request_token
      req = sso_call(hok_token_request)

      unless req.is_a?(Net::HTTPSuccess)
        resp = Nokogiri::XML(req.body)
        resp.remove_namespaces!
        raise(resp.at_xpath('//Envelope/Body/Fault/faultstring/text()'))
      end

      extract_assertion(req.body)
    end

    def sign_request(request)
      raise('Need SAML2 assertion') unless @assertion
      raise('No SAML2 assertion ID') unless @assertion_id

      request_id = generate_id
      timestamp_id = generate_id

      request = request.is_a?(String) ? Nokogiri::XML(request) : request
      builder = Nokogiri::XML::Builder.new do |xml|
        xml[:soap].Header(Hash[NAMESPACES.map { |ns, uri| ["xmlns:#{ns}", uri] }]) do
          xml[:wsse].Security do
            wsu_timestamp(xml, timestamp_id)
            ds_signature(xml, request_id, timestamp_id) do |x|
              x[:wsse].SecurityTokenReference('wsse11:TokenType' => TOKEN_PROFILE) do
                x[:wsse].KeyIdentifier(
                  @assertion_id,
                  'ValueType' => 'http://docs.oasis-open.org/wss/oasis-wss-saml-token-profile-1.1#SAMLID'
                )
              end
            end
          end
        end
      end

      # To avoid Nokogiri mangling the token, we replace it as a string
      # later on. Figure out a way around this.
      builder.doc.at_xpath('//soap:Header/wsse:Security/wsu:Timestamp').add_previous_sibling(Nokogiri::XML::Text.new('SAML_ASSERTION_PLACEHOLDER', builder.doc))

      request.at_xpath('//soap:Envelope', NAMESPACES).tap do |e|
        NAMESPACES.each do |ns, uri|
          e.add_namespace(ns.to_s, uri)
        end
      end
      request.xpath('//soap:Envelope/soap:Body').each do |body|
        body.add_previous_sibling(builder.doc.root)
        body.add_namespace('wsu', NAMESPACES[:wsu])
        body['wsu:Id'] = request_id
      end

      signed = sign(request)
      signed.gsub!('SAML_ASSERTION_PLACEHOLDER', @assertion.to_xml(:indent => 0, :save_with => Nokogiri::XML::Node::SaveOptions::AS_XML).strip)

      signed
    end

    # We default to Issue, since that's all we currently need.
    def sso_call(body)
      sso_url = URI::HTTPS.build(:host => @host, :port => @port, :path => @path)
      http = Net::HTTP.new(sso_url.host, sso_url.port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE if @insecure

      req = Net::HTTP::Post.new(sso_url.request_uri)
      req.add_field('Accept', 'text/xml, multipart/related')
      req.add_field('User-Agent', "VMware/RbVmomi #{RbVmomi::VERSION}")
      req.add_field('SOAPAction', 'http://docs.oasis-open.org/ws-sx/ws-trust/200512/RST/Issue')
      req.content_type = 'text/xml; charset="UTF-8"'
      req.body = body

      http.request(req)
    end

    private

    def hok_token_request
      request_id = generate_id
      security_token_id = generate_id
      signature_id = generate_id
      timestamp_id = generate_id

      datum = Time.now.utc
      created_at = datum.iso8601
      token_expires_at = (datum + 1800).iso8601

      builder = Nokogiri::XML::Builder.new do |xml|
        xml[:soap].Envelope(Hash[NAMESPACES.map { |ns, uri| ["xmlns:#{ns}", uri] }]) do
          xml[:soap].Header do
            xml[:wsse].Security do
              wsu_timestamp(xml, timestamp_id, datum)
              wsse_username_token(xml)
              wsse_binary_security_token(xml, security_token_id)
              ds_signature(xml, request_id, timestamp_id, signature_id) do |x|
                x[:wsse].SecurityTokenReference do
                  x[:wsse].Reference(
                    'URI' => "##{security_token_id}",
                    'ValueType' => BST_PROFILE
                  )
                end
              end
            end
          end
          xml[:soap].Body('wsu:Id' => request_id) do
            xml[:wst].RequestSecurityToken do
              xml[:wst].TokenType(TOKEN_TYPE)
              xml[:wst].RequestType('http://docs.oasis-open.org/ws-sx/ws-trust/200512/Issue')
              xml[:wst].Lifetime do
                xml[:wsu].Created(created_at)
                xml[:wsu].Expires(token_expires_at)
              end
              xml[:wst].Renewing('Allow' => 'false', 'OK' => 'false')
              xml[:wst].KeyType('http://docs.oasis-open.org/ws-sx/ws-trust/200512/PublicKey')
              xml[:wst].SignatureAlgorithm(SIGNATURE_METHOD)
              xml[:wst].Delegatable('false')
            end
            xml[:wst].UseKey('Sig' => signature_id)
          end
        end
      end

      sign(builder.doc)
    end

    def extract_assertion(sso_response)
      sso_response = Nokogiri::XML(sso_response) if sso_response.is_a?(String)
      namespaces = sso_response.collect_namespaces

      # Doesn't matter that usually there's more than one NS with the same
      # URI - either will work for XPath. We just don't want to hardcode
      # xmlns:saml2.
      token_ns = namespaces.find { |_, uri| uri == TOKEN_TYPE }.first.gsub(/^xmlns:/, '')

      @assertion = sso_response.at_xpath("//#{token_ns}:Assertion", namespaces)
      @assertion_id = @assertion.at_xpath("//#{token_ns}:Assertion/@ID", namespaces).value
    end

    def sign(doc)
      signature_digest_references = doc.xpath('/soap:Envelope/soap:Header/wsse:Security/ds:Signature/ds:SignedInfo/ds:Reference/@URI', doc.collect_namespaces).map { |a| a.value.sub(/^#/, '') }
      signature_digest_references.each do |ref|
        data = doc.at_xpath("//*[@wsu:Id='#{ref}']", doc.collect_namespaces)
        digest = Base64.strict_encode64(Digest::SHA2.new(512).digest(data.canonicalize(C14N_CLASS)))
        digest_tag = doc.at_xpath("/soap:Envelope/soap:Header/wsse:Security/ds:Signature/ds:SignedInfo/ds:Reference[@URI='##{ref}']/ds:DigestValue", doc.collect_namespaces)
        digest_tag.add_child(Nokogiri::XML::Text.new(digest, doc))
      end

      signed_info = doc.at_xpath('/soap:Envelope/soap:Header/wsse:Security/ds:Signature/ds:SignedInfo', doc.collect_namespaces)
      signature = Base64.strict_encode64(@private_key.sign(OpenSSL::Digest::SHA512.new, signed_info.canonicalize(C14N_CLASS)))
      signature_value_tag = doc.at_xpath('/soap:Envelope/soap:Header/wsse:Security/ds:Signature/ds:SignatureValue', doc.collect_namespaces)
      signature_value_tag.add_child(Nokogiri::XML::Text.new(signature, doc))

      doc.to_xml(:indent => 0, :save_with => Nokogiri::XML::Node::SaveOptions::AS_XML).strip
    end

    def load_x509(private_key, certificate)
      @private_key = private_key ? private_key : OpenSSL::PKey::RSA.new(2048)
      if @private_key.is_a? String
        @private_key = OpenSSL::PKey::RSA.new(@private_key)
      end

      @certificate = certificate
      if @certificate && !private_key
        raise(ArgumentError, "Can't generate private key from a certificate")
      end

      if @certificate.is_a? String
        @certificate = OpenSSL::X509::Certificate.new(@certificate)
      end
      # If only a private key is specified, we will generate a certificate.
      unless @certificate
        timestamp = Time.now.utc
        @certificate = OpenSSL::X509::Certificate.new
        @certificate.not_before = timestamp
        @certificate.not_after = timestamp + 3600 # 3600 is 1 hour
        @certificate.subject = OpenSSL::X509::Name.new([
                                                         %w[O VMware],
                                                         %w[OU RbVmomi],
                                                         %W[CN #{@user}]
                                                       ])
        @certificate.issuer = @certificate.subject
        @certificate.serial = rand(2**160)
        @certificate.public_key = @private_key.public_key
        @certificate.sign(@private_key, OpenSSL::Digest::SHA512.new)
      end

      true
    end

    def ds_signature(xml, request_id, timestamp_id, id = nil)
      signature_id = {}
      signature_id['Id'] = id if id
      xml[:ds].Signature(signature_id) do
        ds_signed_info(xml, request_id, timestamp_id)
        xml[:ds].SignatureValue
        xml[:ds].KeyInfo do
          yield xml
        end
      end
    end

    def ds_signed_info(xml, request_id, timestamp_id)
      xml[:ds].SignedInfo do
        xml[:ds].CanonicalizationMethod('Algorithm' => C14N_METHOD)
        xml[:ds].SignatureMethod('Algorithm' => SIGNATURE_METHOD)
        xml[:ds].Reference('URI' => "##{request_id}") do
          xml[:ds].Transforms do
            xml[:ds].Transform('Algorithm' => C14N_METHOD)
          end
          xml[:ds].DigestMethod('Algorithm' => DIGEST_METHOD)
          xml[:ds].DigestValue
        end
        xml[:ds].Reference('URI' => "##{timestamp_id}") do
          xml[:ds].Transforms do
            xml[:ds].Transform('Algorithm' => C14N_METHOD)
          end
          xml[:ds].DigestMethod('Algorithm' => DIGEST_METHOD)
          xml[:ds].DigestValue
        end
      end
    end

    def wsu_timestamp(xml, id, datum = nil)
      datum ||= Time.now.utc
      created_at = datum.iso8601
      expires_at = (datum + 600).iso8601

      xml[:wsu].Timestamp('wsu:Id' => id) do
        xml[:wsu].Created(created_at)
        xml[:wsu].Expires(expires_at)
      end
    end

    def wsse_username_token(xml)
      xml[:wsse].UsernameToken do
        xml[:wsse].Username(@user)
        xml[:wsse].Password(@password)
      end
    end

    def wsse_binary_security_token(xml, id)
      xml[:wsse].BinarySecurityToken(
        Base64.strict_encode64(@certificate.to_der),
        'EncodingType' => ENCODING_METHOD,
        'ValueType' => BST_PROFILE,
        'wsu:Id' => id
      )
    end

    def generate_id
      "_#{SecureRandom.uuid}"
    end
  end
end

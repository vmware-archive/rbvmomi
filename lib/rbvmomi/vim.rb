# Copyright (c) 2011 VMware, Inc.  All Rights Reserved.
require 'rbvmomi'

module RbVmomi

class VIM < Connection
  # Connect to a vSphere SDK endpoint
  #
  # @param [Hash] opts The options hash.
  # @option opts [String]  :host Host to connect to.
  # @option opts [Numeric] :port (443) Port to connect to.
  # @option opts [Boolean] :ssl (true) Whether to use SSL.
  # @option opts [Boolean] :insecure (false) If true, ignore SSL certificate errors.
  # @option opts [String]  :user (root) Username.
  # @option opts [String]  :password Password.
  # @option opts [String]  :path (/sdk) SDK endpoint path.
  # @option opts [Boolean] :debug (false) If true, print SOAP traffic to stderr.
  def self.connect opts
    fail unless opts.is_a? Hash
    fail "host option required" unless opts[:host]
    opts[:user] ||= 'root'
    opts[:password] ||= ''
    opts[:ssl] = true unless opts.member? :ssl
    opts[:insecure] ||= false
    opts[:port] ||= (opts[:ssl] ? 443 : 80)
    opts[:path] ||= '/sdk'
    opts[:ns] ||= 'urn:vim25'
    opts[:rev] = '4.1'
    opts[:debug] = (!ENV['RBVMOMI_DEBUG'].empty? rescue false) unless opts.member? :debug

    new(opts).tap do |vim|
      vim.serviceContent.sessionManager.Login :userName => opts[:user], :password => opts[:password]
    end
  end

  # Return the ServiceInstance
  def serviceInstance
    VIM::ServiceInstance self, 'ServiceInstance'
  end

  # Alias to serviceInstance.RetrieveServiceContent
  def serviceContent
    @serviceContent ||= serviceInstance.RetrieveServiceContent
  end

  # Alias to serviceContent.rootFolder
  def rootFolder
    serviceContent.rootFolder
  end

  alias root rootFolder

  # Alias to serviceContent.propertyCollector
  def propertyCollector
    serviceContent.propertyCollector
  end

  # Alias to serviceContent.searchIndex
  def searchIndex
    serviceContent.searchIndex
  end

  # @private
  def self.extension_path name
    File.join(File.dirname(__FILE__), "vim", "#{name}.rb")
  end

  load_vmodl(ENV['VMODL'] || File.join(File.dirname(__FILE__), "../../vmodl.cdb"))
end

end

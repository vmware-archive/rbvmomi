require 'rbvmomi'

module RbVmomi

class VIM < Connection
  # Connect to a vSphere SDK endpoint
  #
  # Options:
  # * host
  # * port
  # * ssl
  # * insecure
  # * user
  # * password
  # * path
  # * debug
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
    opts[:rev] ||= '4.0'
    opts[:debug] = (!ENV['RBVMOMI_DEBUG'].empty? rescue false) unless opts.member? :debug
    opts[:vim_debug] = (!ENV['RBVMOMI_VIM_DEBUG'].empty? rescue false) unless opts.member? :vim_debug

    new(opts).tap do |vim|
      vim.serviceContent.sessionManager.Login :userName => opts[:user], :password => opts[:password]
    end
  end

  def serviceInstance
    VIM::ServiceInstance self, 'ServiceInstance'
  end

  def serviceContent
    @serviceContent ||= serviceInstance.RetrieveServiceContent
  end

  %w(rootFolder propertyCollector searchIndex).map(&:to_sym).each do |s|
    define_method(s) { serviceContent.send s }
  end

  alias root rootFolder

  load_vmodl(ENV['VMODL'] || File.join(File.dirname(__FILE__), "../../vmodl.cdb"))
end

end

require 'rbvmomi/vim_extensions'

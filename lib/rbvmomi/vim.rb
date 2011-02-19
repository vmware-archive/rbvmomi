require 'rbvmomi'

module RbVmomi

class VIM < Connection
  include RbVmomi::BasicTypes

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
    opts[:debug] = (!ENV['RBVMOMI_DEBUG'].empty? rescue false) unless opts.member? :debug
    opts[:vim_debug] = (!ENV['RBVMOMI_VIM_DEBUG'].empty? rescue false) unless opts.member? :vim_debug

    RbVmomi::Connection.new(opts).tap do |vim|
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

#private

  def self.load_type sym
    const_set sym, @loader.lookup_type(sym.to_s)
  end

  def self.const_missing sym
    name = sym.to_s
    if @loader.has_type? name
      load_type name
    else
      super
    end
  end

  def self.method_missing sym, *a
    if @loader.has_type? sym.to_s
      const_get(sym).new *a
    else
      super
    end
  end

  vmodl_fn = ENV['VMODL'] || File.join(File.dirname(__FILE__), "../../vmodl.cdb")
  @loader = RbVmomi::TypeLoader.new vmodl_fn
  Object.constants.select { |x| @loader.has_type? x.to_s }.each { |x| load_type x.to_s }
end

end

require 'rbvmomi/vim_extensions'

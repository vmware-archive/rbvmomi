# Copyright (c) 2011-2017 VMware, Inc.  All Rights Reserved.
# SPDX-License-Identifier: MIT

require 'rbvmomi'
require 'timeout'

# Win32::SSPI is part of core on Windows
begin
  require 'win32/sspi'
rescue LoadError
end
WIN32 = (defined? Win32::SSPI)

module RbVmomi

# A connection to one vSphere SDK endpoint.
# @see #serviceInstance
class VIM < Connection
  # Connect to a vSphere SDK endpoint
  #
  # @param [Hash] opts The options hash.
  # @option opts [String]  :host Host to connect to.
  # @option opts [Numeric] :port (443) Port to connect to.
  # @option opts [Boolean] :ssl (true) Whether to use SSL.
  # @option opts [Boolean] :insecure (false) If true, ignore SSL certificate errors.
  # @option opts [String]  :cookie If set, use cookie to connect instead of user/password
  # @option opts [String]  :user (root) Username.
  # @option opts [String]  :password Password.
  # @option opts [String]  :path (/sdk) SDK endpoint path.
  # @option opts [Boolean] :debug (false) If true, print SOAP traffic to stderr.
  # @option opts [String]  :operation_id If set, use for operationID
  def self.connect opts
    fail unless opts.is_a? Hash
    fail "host option required" unless opts[:host]
    opts[:cookie] ||= nil
    opts[:user] ||= (WIN32 ? ENV['USERNAME'].dup : 'root')
    opts[:password] ||= ''
    opts[:ssl] = true unless opts.member? :ssl or opts[:"no-ssl"]
    opts[:insecure] ||= false
    opts[:port] ||= (opts[:ssl] ? 443 : 80)
    opts[:path] ||= '/sdk'
    opts[:ns] ||= 'urn:vim25'
    rev_given = opts[:rev] != nil
    opts[:rev] = '6.5' unless rev_given
    opts[:debug] = (!ENV['RBVMOMI_DEBUG'].empty? rescue false) unless opts.member? :debug

    conn = new(opts).tap do |vim|
      unless opts[:cookie]
        if WIN32 && opts[:password] == ''
            # Attempt login by SSPI if no password specified on Windows
            negotiation = Win32::SSPI::NegotiateAuth.new opts[:user], ENV['USERDOMAIN'].dup
            begin
              vim.serviceContent.sessionManager.LoginBySSPI :base64Token => negotiation.get_initial_token
            rescue RbVmomi::Fault => fault
              if !fault.fault.is_a?(RbVmomi::VIM::SSPIChallenge)
                raise
              else
                vim.serviceContent.sessionManager.LoginBySSPI :base64Token => negotiation.complete_authentication(fault.base64Token)
              end
            end
        else
            vim.serviceContent.sessionManager.Login :userName => opts[:user], :password => opts[:password]
        end
      end
      unless rev_given
        rev = vim.serviceContent.about.apiVersion
        vim.rev = [rev, '6.5'].min
      end
    end

    at_exit { conn.close }
    conn
  end

  def close
    serviceContent.sessionManager.Logout
  rescue RbVmomi::Fault => e
    $stderr.puts(e.message) if debug
  ensure
    self.cookie = nil
    super
  end

  def rev= x
    super
    @serviceContent = nil
  end

  # Return the ServiceInstance
  #
  # The ServiceInstance is the root of the vSphere inventory.
  # @see http://www.vmware.com/support/developer/vc-sdk/visdk41pubs/ApiReference/vim.ServiceInstance.html
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
  def pretty_print pp
    pp.text "VIM(#{@opts[:host]})"
  end

  def instanceUuid
    serviceContent.about.instanceUuid
  end

  def get_log_lines logKey, lines=5, start=nil, host=nil
    diagMgr = self.serviceContent.diagnosticManager
    if !start
      log = diagMgr.BrowseDiagnosticLog(:host => host, :key => logKey, :start => 999999999)
      lineEnd = log.lineEnd
      start = lineEnd - lines
    end
    start = start < 0 ? 0 : start
    log = diagMgr.BrowseDiagnosticLog(:host => host, :key => logKey, :start => start)
    if log.lineText.size > 0
      [log.lineText.slice(-lines, log.lineText.size), log.lineEnd]
    else
      [log.lineText, log.lineEnd]
    end
  end

  # Invoke command on a VirtualMachine
  # @param username [String] the username for access to the VirtualMachine
  # @param password [String] the password for access to the VirtualMachine
  # @param command [String] the command to execute on the VirtualMachine
  # @param timeout (optional) [Fixnum] timeout to wait before killing the task, defaults to nil
  # @param interval (optinal) [Fixnum] interval between checkinf if process is completed
  # @param shell (optional) [String] the optional shell to use, defaults to /bin/bash
  def invoke_cmd(options={})
    fail "vm required" unless options[:vm].is_a? RbVmomi::VIM::VirtualMachine
    fail "username required" unless options[:username].is_a? String
    fail "password required" unless options[:password].is_a? String
    fail "command required" unless options[:command].is_a? String
    options[:shell] ||= '/bin/bash'
    options[:timeout] ||= nil
    options[:interval] ||= 2

    @timeout = options[:timeout]
    @interval = options[:interval]
    @vm = options[:vm]

    @out_file = "/tmp/#{(0...8).map { (65 + rand(26)).chr }.join}"

    # Run command
    @npa = RbVmomi::VIM.NamePasswordAuthentication(:username => options[:username], :password => options[:password], :interactiveSession => false)
    @spec = RbVmomi::VIM.GuestProgramSpec(:programPath => options[:shell], :arguments => "-c '#{options[:command]}' > #{@out_file} 2>&1")
    @pid = self.serviceContent.guestOperationsManager.processManager.StartProgramInGuest(:vm => @vm, :auth => @npa, :spec => @spec)

    # Wait for command to finish
    begin
      status = Timeout::timeout(@timeout) do
        while self.serviceContent.guestOperationsManager.processManager.ListProcessesInGuest(:vm => @vm, :auth => @npa, :pid => @pid).first.endTime.nil?
          sleep @interval
        end
      end
    rescue Timeout::Error          
      begin
        self.serviceContent.guestOperationsManager.processManager.TerminateProcessInGuest(:vm => @vm, :auth => @npa, :pid => @pid)
      # If process not found, assume it exited cleanly
      rescue RbVmomi::Fault::GuestProcessNotFound
        break
      end
      fail "Timeout reached while executing #{options[:command]}\nProcess terminated"
    end

    # Get process information
    @return = self.serviceContent.guestOperationsManager.processManager.ListProcessesInGuest(:vm => @vm, :auth => @npa, :pid => @pid).first

    # Retrieve process output
    @local_path = @vm.download(self, @out_file, @npa)
    @vm.delete_file(self, @out_file, @npa)

    # Stuff output into modified class object
    @return.cmd_output = File.read(@local_path)
    `rm #{@local_path}`

    @return
  end

  def get_log_keys host=nil
    diagMgr = self.serviceContent.diagnosticManager
    keys = []
    diagMgr.QueryDescriptions(:host => host).each do |desc|
      keys << "#{desc.key}"
    end
    keys
  end

  add_extension_dir File.join(File.dirname(__FILE__), "vim")
  (ENV['RBVMOMI_VIM_EXTENSION_PATH']||'').split(':').each { |dir| add_extension_dir dir }

  load_vmodl(ENV['VMODL'] || File.join(File.dirname(__FILE__), "../../vmodl.db"))
end

end

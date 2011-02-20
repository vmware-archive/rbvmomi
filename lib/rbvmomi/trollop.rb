# Copyright (c) 2011 VMware, Inc.  All Rights Reserved.
require 'trollop'

module Trollop #:nodoc:
class Parser
  def rbvmomi_connection_opts
    opt :host, "host", type: :string, short: 'o', default: ENV['RBVMOMI_HOST']
    opt :port, "port", type: :int, short: :none, default: (ENV.member?('RBVMOMI_PORT') ? ENV['RBVMOMI_PORT'].to_i : 443)
    opt :"no-ssl", "don't use ssl", short: :none, default: (ENV['RBVMOMI_SSL'] == '0') 
    opt :insecure, "don't verify ssl certificate", short: 'k', default: (ENV['RBVMOMI_INSECURE'] == '1')
    opt :user, "username", short: 'u', default: (ENV['RBVMOMI_USER'] || 'root')
    opt :password, "password", short: 'p', default: (ENV['RBVMOMI_PASSWORD'] || '')
    opt :path, "SOAP endpoint path", short: :none, default: (ENV['RBVMOMI_PATH'] || '/sdk')
    opt :debug, "Log SOAP messages", short: 'd'
  end

  def rbvmomi_datacenter_opt
    opt :datacenter, "datacenter", type: :string, short: "D", default: (ENV['RBVMOMI_DATACENTER'] || 'ha-datacenter')
  end

  def rbvmomi_folder_opt
    opt :folder, "VM folder", type: :string, short: "F", default: (ENV['RBVMOMI_FOLDER'] || '')
  end

  def rbvmomi_computer_opt
    opt :computer, "Compute resource", type: :string, short: "R", default: ENV['RBVMOMI_COMPUTER']
  end

  def rbvmomi_datastore_opt
    opt :datastore, "Datastore", short: 's', default: (ENV['RBVMOMI_DATASTORE'] || 'datastore1')
  end
end
end

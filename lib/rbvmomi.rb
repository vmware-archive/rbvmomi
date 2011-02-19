# Copyright (c) 2010 VMware, Inc.  All Rights Reserved.
require 'rbvmomi/connection'

module RbVmomi #:nodoc:all

class Fault < StandardError
  attr_reader :fault

  def initialize msg, fault
    super "#{fault.class.wsdl_name}: #{msg}"
    @fault = fault
  end

  def method_missing *a
    @fault.send *a
  end
end

def self.fault msg, fault
  Fault.new(msg, fault)
end

end

require 'rbvmomi/vim'

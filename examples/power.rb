# frozen_string_literal: true
# Copyright (c) 2011-2017 VMware, Inc.  All Rights Reserved.
# SPDX-License-Identifier: MIT

require "optimist"
require "rbvmomi"
require "rbvmomi/optimist"

VIM = RbVmomi::VIM
CMDS = %w(on off reset suspend destroy).freeze

opts = Optimist.options do
  banner <<~EOS
    Perform VM power operations.
    
    Usage:
        power.rb [options] cmd VM
    
    Commands: #{CMDS * ' '}
    
    VIM connection options:
  EOS

  rbvmomi_connection_opts

  text <<~EOS
    
    VM location options:
  EOS

  rbvmomi_datacenter_opt

  text <<~EOS
    
    Other options:
  EOS

  stop_on CMDS
end

cmd = ARGV[0] or Optimist.die("no command given")
vm_name = ARGV[1] or Optimist.die("no VM name given")
Optimist.die("must specify host") unless opts[:host]

vim = VIM.connect opts

dc = vim.service_instance.content.rootFolder.traverse(opts[:datacenter], VIM::Datacenter) or abort "datacenter not found"
vm = dc.vmFolder.traverse(vm_name, VIM::VirtualMachine) or abort "VM not found"

case cmd
when "on"
  vm.PowerOnVM_Task.wait_for_completion
when "off"
  vm.PowerOffVM_Task.wait_for_completion
when "reset"
  vm.ResetVM_Task.wait_for_completion
when "suspend"
  vm.SuspendVM_Task.wait_for_completion
when "destroy"
  vm.Destroy_Task.wait_for_completion
else
  abort "invalid command"
end

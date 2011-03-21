#!/usr/bin/env ruby
require 'trollop'
require 'rbvmomi'
require 'rbvmomi/trollop'

VIM = RbVmomi::VIM

opts = Trollop.options do
  banner <<-EOS
Clone a VM.

Usage:
    clone_vm.rb [options]

VIM connection options:
    EOS

    rbvmomi_connection_opts

    text <<-EOS

VM location options:
    EOS

    rbvmomi_datacenter_opt

    text <<-EOS

Other options:
  EOS
end

Trollop.die("must specify host") unless opts[:host]
ARGV.size == 2 or abort "must specify VM source name and VM target name"
vm_source = ARGV[0]
vm_target = ARGV[1]

vim = VIM.connect opts
dc = vim.serviceInstance.find_datacenter(opts[:datacenter]) or abort "datacenter not found"
vm = dc.find_vm(vm_source) or abort "VM not found"

spec = VIM.VirtualMachineCloneSpec(:location => VIM.VirtualMachineRelocateSpec,
                                   :powerOn => false,
                                   :template => false)

vm.CloneVM_Task(:folder => vm.parent, :name => vm_target, :spec => spec).wait_for_completion

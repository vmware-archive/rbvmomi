#!/usr/bin/env ruby
# frozen_string_literal: true

# Copyright (c) 2011-2017 VMware, Inc.  All Rights Reserved.
# SPDX-License-Identifier: MIT

require "optimist"
require "rbvmomi"
require "rbvmomi/optimist"

VIM = RbVmomi::VIM

opts = Optimist.options do
  banner <<~EOS
    Delete a disk from a VM.
    
    Usage:
        delete_disk_from_vm.rb [options] vm_name disk_unit_number
    
    VIM connection options:
  EOS

  rbvmomi_connection_opts

  text <<~EOS
    
    VM location options:
  EOS

  rbvmomi_datacenter_opt
end

Optimist.die("must specify host") unless opts[:host]
ARGV.size == 2 or abort "must specify VM name and disk unit number"
vm_name          = ARGV[0]
disk_unit_number = ARGV[1].to_i

vim = VIM.connect opts
dc = vim.service_instance.find_datacenter(opts[:datacenter]) or abort "datacenter not found"
vm = dc.find_vm(vm_name) or abort "VM not found"

disk = vm.config.hardware.device.detect do |device|
  device.is_a?(VIM::VirtualDisk) && device.unitNumber == disk_unit_number
end

raise "Disk #{disk_unit_number} not found" if disk.nil?

spec = VIM::VirtualMachineConfigSpec(
  deviceChange: [
    VIM::VirtualDeviceConfigSpec(
      device: disk,
      fileOperation: VIM.VirtualDeviceConfigSpecFileOperation(:destroy),
      operation: VIM::VirtualDeviceConfigSpecOperation(:remove)
    )
  ]
)

vm.ReconfigVM_Task(spec: spec).wait_for_completion

#!/usr/bin/env ruby
# frozen_string_literal: true

# Copyright (c) 2011-2017 VMware, Inc.  All Rights Reserved.
# SPDX-License-Identifier: MIT

require "optimist"
require "rbvmomi"
require "rbvmomi/optimist"

VIM = RbVmomi::VIM
CMDS = %w(get set).freeze
BEHAVIOR = %w(fullyAutomated manual partiallyAutomated default).freeze

opts = Optimist.options do
  banner <<~EOS
    Configure VM DRS behavior.
    
    Usage:
        vm_drs_behavior.rb [options] VM get
        vm_drs_behavior.rb [options] VM set #{BEHAVIOR.join('|')}
    
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

Optimist.die("must specify host") unless opts[:host]

vm_name = ARGV[0] or Optimist.die("no VM name given")
cmd = ARGV[1] or Optimist.die("no command given")
abort "invalid command" unless CMDS.member? cmd

vim = VIM.connect opts
dc = vim.service_instance.find_datacenter(opts[:datacenter]) or abort "datacenter not found"
vm = dc.find_vm(vm_name) or abort "VM not found"

cluster = vm.runtime.host.parent
config = cluster.configurationEx.drsVmConfig.select { |c| c.key.name == vm.name }.first
default = cluster.configurationEx.drsConfig.defaultVmBehavior

case cmd
when "get"
  behavior = if config
               config.behavior
             else
               "#{default} (default)"
             end
  puts "#{vm.name} is #{behavior}"
when "set"
  behavior = ARGV[2] or Optimist.die("no behavior given")
  abort "invalid behavior" unless BEHAVIOR.member? behavior

  behavior = default if behavior == "default"
  vm_spec =
    VIM.ClusterDrsVmConfigSpec(operation: VIM.ArrayUpdateOperation(config ? "edit" : "add"),
                               info: VIM.ClusterDrsVmConfigInfo(key: vm,
                                                                   behavior: VIM.DrsBehavior(behavior)))
  spec = VIM.ClusterConfigSpecEx(drsVmConfigSpec: [vm_spec])
  cluster.ReconfigureComputeResource_Task(spec: spec, modify: true).wait_for_completion
end

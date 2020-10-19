# frozen_string_literal: true
# Author: Raul Mahiques - Red Hat 2020
# Based on "annotate.rb" ( https://github.com/vmware/rbvmomi/blob/a5867550bef9535c17f7bedd947fe336151347af/examples/annotate.rb )
# License MIT ( https://mit-license.org/ )
# SPDX-License-Identifier: MIT

require 'optimist'
require 'rbvmomi'
require 'rbvmomi/optimist'
require 'yaml'

VIM  = RbVmomi::VIM
CMDS = %w(get set)

opts = Optimist.options do
  banner <<~EOS
    Set a custom value for a VM.
    
    Usage:
        customAttributes.rb [options] <VM nane> get
        customAttributes.rb [options] <VM name> set <"Custom Attribute"> <"Custom Attribute value">
    
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

vm_name = ARGV[0] or Optimist.die('no VM name given')
cmd     = ARGV[1] or Optimist.die('no command given')
abort 'invalid command' unless CMDS.member? cmd
Optimist.die('must specify host') unless opts[:host]

vim = VIM.connect opts
dc  = vim.serviceInstance.find_datacenter(opts[:datacenter]) or abort 'datacenter not found'
vm  = dc.find_vm(vm_name) or abort 'VM not found'

case cmd
when 'get'
  puts "Custom Attributes for \"#{vm_name}\""
  vm.value.each do |val|
    fname = 'unknown_field'
    vm.availableField.each do |af|
      if af.key == val.key
        fname = af.name
      end
    end
    puts "\t#{fname}: \"#{val.value}\""
  end
when 'set'
  arrayCustomAttributes = []
  customAttribute       = ARGV[2] or Optimist.die('no Custom Attribute given')
  customAttributeValue  = ARGV[3] or Optimist.die('no value for the Custom Attribute given')
  # Verify the Custom Attribute exists
  exists = 0
  vm.availableField.each do |af|
    if customAttribute == af.name
      exists = 1
      break
    else
      arrayCustomAttributes << af.name
    end
  end
  exists == 1 or abort "Field \"#{customAttribute}\" doesn't exists\nPlease use one of the following:\n\t#{arrayCustomAttributes.join("\n\t")}"
  vm.setCustomValue({'key' => "#{customAttribute}", :value => "#{customAttributeValue}"})
end

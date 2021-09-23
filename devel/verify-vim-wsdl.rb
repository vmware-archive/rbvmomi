#!/usr/bin/env ruby
# frozen_string_literal: true

require 'active_support/core_ext/enumerable'
require 'active_support/inflector'
require 'optimist'
require 'pathname'
require 'rbvmomi'
require 'wsdl/parser'

def parse_args(args)
  opts = Optimist.options do
    usage <<~HELP
      Usage:
      verify-vim-wsdl.rb [path to wsdl] [path to vmodl.db]
    HELP

    opt :fix, 'Optionally fix the wsdl types in the vmodl.db', type: :boolean, default: false
  end

  Optimist.die('You must provide a wsdl file and a vmodl file') if args.count < 2

  wsdl_path = Pathname.new(args.shift).expand_path
  Optimist.die('You must pass a path to a wsdl file') if !wsdl_path.exist?

  vmodl_path = Pathname.new(args.shift).expand_path
  Optimist.die('You must pass a path to the vmodl.db file') if !vmodl_path.exist?

  return wsdl_path, vmodl_path, opts
end

def load_wsdl(path)
  # WSDL includes have to resolve in the local directory so we have to
  # change working directories to where the wsdl is
  Dir.chdir(path.dirname) do
    WSDL::Parser.new.parse(path.read)
  end
end

def load_vmodl(path)
  Marshal.load(path.read)
end

def dump_vmodl(vmodl, path)
  File.write(path, Marshal.dump(vmodl))
end

def wsdl_to_vmodl_type(type)
  case type.source
  when /vim25:/
    vmodl_type = type.name
    vmodl_type = 'ManagedObject' if vmodl_type == 'ManagedObjectReference'
  when /xsd:/
    vmodl_type = type.source
  else
    raise ArgumentError, "Unrecognized wsdl type: [#{type}]"
  end

  vmodl_type
end

# Normalize the type, some of these don't have RbVmomi equivalents such as xsd:long
# and RbVmomi uses ManagedObjects not ManagedObjectReferences as parameters
def wsdl_constantize(type)
  type = type.split(':').last
  type = 'int'           if %w[long short byte].include?(type)
  type = 'float'         if type == 'double'
  type = 'binary'        if type == 'base64Binary'
  type = 'ManagedObject' if type == 'ManagedObjectReference'

  type = type.camelcase
  type.safe_constantize || "RbVmomi::BasicTypes::#{type}".safe_constantize || "RbVmomi::VIM::#{type}".safe_constantize
end

wsdl_path, vmodl_path, options = parse_args(ARGV)

vim   = load_wsdl(wsdl_path)
vmodl = load_vmodl(vmodl_path)

# Loop through the ComplexTypes in the WSDL and compare their types
# to the types which are defined in the vmodl.db
wsdl_types_by_name = vim.collect_complextypes.index_by { |type| type.name.name }

wsdl_types_by_name.each_value do |type|
  type_name = type.name.name
  next if type_name.match?(/^ArrayOf/) || type_name.match(/RequestType$/)

  vmodl_data = vmodl[type_name]

  # If a type exists in the WSDL but not in the vmodl.db this usually
  # indicates that it was added in a newer version than the current
  # vmodl.db supports.
  #
  # Print a warning that the type is missing and skip it.
  if vmodl_data.nil?
    puts " #{type_name} is missing"
    next unless options[:fix]

    base_class           = wsdl_types_by_name[type.complexcontent.extension.base.name]
    inherited_properties = base_class.elements.map { |element| element.name.name }
    properties           = type.elements.reject { |e| inherited_properties.include?(e.name.name) }

    vmodl_data = {
      'kind'      => 'data',
      'props'     => properties.map do |element|
        {
          'name'           => element.name.name,
          'is-optional'    => element.minoccurs == 0,
          'is-array'       => element.maxoccurs != 1,
          'version-id-ref' => nil,
          'wsdl_type'      => wsdl_to_vmodl_type(element.type)
        }
      end,
      'wsdl_base' => type.complexcontent.extension.base.name
    }

    vmodl[type_name] = vmodl_data
    vmodl['_typenames']['_typenames'] << type_name
  end

  # Index the properties by name to make it simpler to find later
  elements_by_name = type.elements.index_by { |e| e.name.name }

  # Loop through the properties defined in the vmodl.db for this type and
  # compare the type to that property as defined in the wsdl.
  vmodl_data['props'].each do |vmodl_prop|
    wsdl_prop = elements_by_name[vmodl_prop['name']]
    next if wsdl_prop.nil?

    vmodl_klass = wsdl_constantize(vmodl_prop['wsdl_type'])
    wsdl_klass  = wsdl_constantize(wsdl_prop.type.source)

    # The vmodl class should be equal to or a subclass of the one in the wsdl.
    # Example of a subclass is e.g. VirtualMachine.host is defined as a HostSystem
    # in the vmodl.db but it is a ManagedObjectReference in the wsdl.
    unless vmodl_klass <= wsdl_klass
      puts "#{type_name}.#{vmodl_prop["name"]} #{wsdl_klass.wsdl_name} doesn't match #{vmodl_klass.wsdl_name}"
      vmodl_prop['wsdl_type'] = wsdl_klass.wsdl_name if options[:fix]
    end
  end
end

dump_vmodl(vmodl, vmodl_path) if options[:fix]

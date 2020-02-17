#!/usr/bin/env ruby

require 'active_support/core_ext/enumerable'
require 'active_support/inflector'
require "optimist"
require "pathname"
require "rbvmomi"
require "wsdl/parser"

def parse_args(args)
  opts = Optimist.options do
    banner <<~HELP
      Usage:
      verify-vim-wsdl.rb [path to wsdl] [path to vmodl.db]

      --fix       Fix the wsdl types
      --help, -h  Print this message and exit
    HELP

    opt :fix, "Optionally fix the wsdl types in the vmodl.db", :type => :boolean, :default => false
  end

  Optimist.die("You must provide a wsdl file and a vmodl file") if args.count < 2

  wsdl_path = Pathname.new(args.shift)
  Optimist.die("You must pass a path to a wsdl file") if !wsdl_path.exist?

  vmodl_path = Pathname.new(args.shift)
  Optimist.die("You must pass a path to the vmodl.db file") if !vmodl_path.exist?

  return wsdl_path, vmodl_path, opts
end

def indirectory(dir)
  saved_dir = Dir.getwd
  Dir.chdir(dir)
  yield
ensure
  Dir.chdir(saved_dir)
end

def load_wsdl(path)
  workingdir = Dir.getwd

  # WSDL includes have to resolve in the local directory so we have to
  # change working directories to where the wsdl is
  indirectory(path.dirname) do
    WSDL::Parser.new.parse(path.read)
  end
end

def load_vmodl(path)
  Marshal.load(path.read)
end

def dump_vmodl(vmodl, path)
  File.write(path, Marshal.dump(vmodl))
end

# Normalize the type, some of these don't have RbVmomi equivalents such as xsd:long
# and RbVmomi uses ManagedObjects not ManagedObjectReferences as parameters
def wsdl_constantize(type)
  type = type.split(":").last
  type = "int"           if %w[long short byte].include?(type)
  type = "float"         if type == "double"
  type = "binary"        if type == "base64Binary"
  type = "ManagedObject" if type == "ManagedObjectReference"

  type = type.camelcase
  type.safe_constantize || "RbVmomi::BasicTypes::#{type}".safe_constantize || "RbVmomi::VIM::#{type}".safe_constantize
end

wsdl_path, vmodl_path, options = parse_args(ARGV)

vim   = load_wsdl(wsdl_path)
vmodl = load_vmodl(vmodl_path)

vim.collect_complextypes.each do |type|
  type_name = type.name.name
  vmodl_data = vmodl[type_name]

  next if vmodl_data.nil?

  elements_by_name = type.elements.index_by { |e| e.name.name }
  vmodl_data["props"].each do |vmodl_prop|
    wsdl_prop = elements_by_name[vmodl_prop["name"]]
    next if wsdl_prop.nil?

    vmodl_klass = wsdl_constantize(vmodl_prop["wsdl_type"])
    wsdl_klass  = wsdl_constantize(wsdl_prop.type.source)

    unless vmodl_klass <= wsdl_klass
      puts "#{type_name}.#{vmodl_prop["name"]} #{wsdl_klass.wsdl_name} doesn't match #{vmodl_klass.wsdl_name}"
      vmodl_prop["wsdl_type"] = wsdl_klass.wsdl_name if options[:fix]
    end
  end
end

dump_vmodl(vmodl, vmodl_path) if options[:fix]

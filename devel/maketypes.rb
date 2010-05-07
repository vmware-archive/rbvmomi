require 'yaml'
require 'pp'
require 'set'

VMODL = YAML.load_file(ARGV.first || fail("must specify vmodl file"))

module VIM

def self.const_missing sym
	puts "lazy loading class #{sym}"
	load sym
end

def self.load sym
	const_set sym, make_type(sym)
end

def self.make_data_type name, desc
	superclass = const_get(desc['wsdl_base'].to_sym)
	Class.new(superclass).tap do |klass|
		klass.initialize name, desc['props']
	end
end

def self.make_managed_type name, desc
	superclass = const_get(desc['wsdl_base'].to_sym)
	Class.new(superclass).tap do |klass|
		klass.initialize name, desc['props'], desc['methods']
	end
end

def self.make_enum_type name, desc
	Class.new(Enum).tap do |klass|
		klass.initialize name, desc['values']
	end
end

def self.make_type name
	name = name.to_s
	if desc = VMODL['data'][name]
		make_data_type name, desc
	elsif desc = VMODL['managed'][name]
		make_managed_type name, desc
	elsif desc = VMODL['enum'][name]
		make_enum_type name, desc
	else fail "unknown VMODL type #{name}"
	end
end

class Base
	class << self
		def initialize name=self.name
			@name = name
		end

		def to_s
			@name
		end
	end

	initialize
end

class ObjectWithProperties < Base
	class << self
		attr_accessor :props_desc

		def initialize name=self.name, props=[]
			super name
			@props_desc = props
			@props_desc.each do |d|
				sym = d['name'].to_sym
				define_method(sym) { @props[sym] }
				define_method(:"#{sym}=") { |x| @props[sym] = x }
			end
		end

		# XXX cache
		def full_props_desc
			(self == ObjectWithProperties ? [] : superclass.full_props_desc) + props_desc
		end

		def find_prop_desc name
			full_props_desc.find { |x| x['name'] == name.to_s }
		end
	end

	initialize
end

class ObjectWithMethods < ObjectWithProperties
	class << self
		attr_accessor :methods_desc

		def initialize name=self.name, props=[], methods={}
			super name, props
			@methods_desc = methods

			@methods_desc.each do |k,d|
				sym = k.to_sym
				define_method(sym) { call sym }
			end
		end

		# XXX cache
		def full_methods_desc
			(self == ObjectWithMethods ? {} : superclass.full_methods_desc).merge methods_desc
		end
	end

	initialize
end

class DataObject < ObjectWithProperties
	def initialize props={}
		@props = props
		@props.each do |k,v|
			fail "unexpected property name #{k}" unless self.class.find_prop_desc(k)
		end
	end

	initialize
end

class ManagedObject < ObjectWithMethods
	def initialize ref
		@ref = ref
	end

	initialize
end

class Enum < Base
	class << self
		attr_accessor :values

		def initialize name=self.name, values=[]
			super name
			@values = values
		end
	end

	attr_reader :value

	def initialize value
		@value = value
	end

	initialize
end

class MethodFault < DataObject
	initialize
end

class RuntimeFault < DataObject
	initialize
end

class MethodName < String
end

class PropertyPath < String
end

class TypeName < String
end

end

typenames = VMODL.map { |x,v| v.keys }.flatten
self.class.constants.select { |x| typenames.member? x.to_s }.each { |x| VIM.load x }

=begin
nic = VIM::VirtualE1000.new :key => 1000
pp nic.key
nic.key = 2
pp nic.key
=end

if false
VMODL['data'].each do |name,desc|
	puts "--"
	VIM.const_get(name.to_sym)
end

VMODL['managed'].each do |name,desc|
	puts "--"
	VIM.const_get(name.to_sym)
end

VMODL['enum'].each do |name,desc|
	puts "--"
	VIM.const_get(name.to_sym)
end
end

cfg = VIM::VirtualMachineConfigSpec.new(
	name: "esx1a",
	guestId: "otherGuest64",
	files: VIM::VirtualMachineFileInfo.new(vmPathName: '[datastore1]'),
	numCPUs: 2,
	memoryMB: 3072,
	deviceChange: [
		VIM::VirtualDeviceConfigSpec.new(
			operation: :add,
			device: VIM::VirtualLsiLogicController.new(
				key: 1000,
				busNumber: 0,
				sharedBus: :noSharing,
			)
		)
	]
)

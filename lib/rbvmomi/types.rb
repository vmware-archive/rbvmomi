require 'yaml'
require 'pp'
require 'set'

module RbVmomi

module VIM

def self.load fn
	@vmodl = YAML.load_file(fn)
	@typenames = @vmodl.map { |x,v| v.keys }.flatten
	Object.constants.select { |x| @typenames.member? x.to_s }.each { |x| load_type x }
end

def self.const_missing sym
	if @typenames.member? sym.to_s
		load_type sym
	else
		super
	end
end

def self.method_missing sym, *a
	if @typenames.member? sym.to_s
		const_get(sym).new *a
	else
		super
	end
end

def self.load_type sym
	const_set sym, make_type(sym)
end

def self.make_type name
	name = name.to_s
	if desc = @vmodl['data'][name]
		make_data_type name, desc
	elsif desc = @vmodl['managed'][name]
		make_managed_type name, desc
	elsif desc = @vmodl['enum'][name]
		make_enum_type name, desc
	else fail "unknown @vmodl type #{name}"
	end
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

class Base
	class << self
		attr_reader :wsdl_name

		def initialize wsdl_name=self.name
			@wsdl_name = wsdl_name
		end

		def to_s
			@wsdl_name
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

	attr_reader :props

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

end

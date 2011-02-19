# Copyright (c) 2010 VMware, Inc.  All Rights Reserved.
require 'cdb'
require 'pp'
require 'set'

module RbVmomi #:nodoc:all

class TypeLoader
	BUILTIN_TYPES = %w(ManagedObject DataObject TypeName PropertyPath ManagedObjectReference MethodName MethodFault LocalizedMethodFault)

	def initialize fn
		@db = CDB.new fn
		@vmodl = Hash.new { |h,k| if e = @db[k] then h[k] = Marshal.load(e) end }
		@typenames = Marshal.load(@db['_typenames']) + BUILTIN_TYPES
    @loaded = Hash.new { |h,k| h[k] = make_type k }
    BUILTIN_TYPES.each { |x| @loaded[x] = RbVmomi::BasicTypes.const_get x }
	end

	def has_type? name
    fail unless name.is_a? String
		@typenames.member? name or @loaded.member? name
	end

  def lookup_type name
    fail unless name.is_a? String
    @loaded[name]
  end

	private

	def make_type name
		name = name.to_s
		desc = @vmodl[name] or fail "unknown VIM type #{name}"
		case desc['kind']
		when 'data' then make_data_type name, desc
		when 'managed' then make_managed_type name, desc
		when 'enum' then make_enum_type name, desc
		else fail desc.inspect
		end
	end

	def make_data_type name, desc
		superclass = lookup_type desc['wsdl_base']
		Class.new(superclass).tap do |klass|
			klass.initialize name, desc['props']
		end
	end

	def make_managed_type name, desc
		superclass = lookup_type desc['wsdl_base']
		Class.new(superclass).tap do |klass|
			klass.initialize name, desc['props'], desc['methods']
		end
	end

	def make_enum_type name, desc
		Class.new(BasicTypes::Enum).tap do |klass|
			klass.initialize name, desc['values']
		end
	end
end

end

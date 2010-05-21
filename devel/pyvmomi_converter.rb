#!/usr/bin/env ruby
require 'pp'
require 'date'
require 'ostruct'
require 'json'
require 'yaml'

BORA="/mts/home5/rlane/dbc/3/bora"
PYVMOMI=BORA + '/build/build/vmodl/obj/generic/pyVmomi'
PYTHON_MODELS=%w(CoreTypes HostdObjects InternalServerObjects ServerObjects)

F_LINK = 1
F_LINKABLE = 2
F_OPTIONAL = 4

VMODL2WSDL = Hash.new { |h,k| raise "VMODL2WSDL failed on #{k.inspect}" }

VMODL2WSDL.merge!(
	'anyType' => 'xsd:anyType',
	'anyType[]' => 'ArrayOfAnyType',
	'boolean' => 'xsd:boolean',
	'boolean[]' => 'ArrayOfBoolean',
	'byte' => 'xsd:byte',
	'byte[]' => 'ArrayOfByte',
	'short' => 'xsd:short',
	'short[]' => 'ArrayOfShort',
	'int' => 'xsd:int',
	'int[]' => 'ArrayOfInt',
	'long' => 'xsd:long',
	'long[]' => 'ArrayOfLong',
	'float' => 'xsd:float',
	'float[]' => 'ArrayOfFloat',
	'double' => 'xsd:float',
	'double[]' => 'ArrayOfDouble',
	'string' => 'xsd:string',
	'string[]' => 'ArrayOfString',
	'vmodl.DateTime' => 'xsd:dateTime',
	'vmodl.DateTime[]' => 'ArrayOfDateTime'
)

%w(DataObject ManagedObject MethodFault MethodName
   PropertyPath RuntimeFault TypeName).each do |x|
	VMODL2WSDL['vmodl.' + x] = x
	VMODL2WSDL['vmodl.' + x + '[]'] = 'ArrayOf' + x
	VMODL2WSDL[x] = x
	VMODL2WSDL[x + '[]'] = 'ArrayOf' + x
end

DATA_TYPES = {}
MANAGED_TYPES = {}
ENUM_TYPES = {}

class ModelBuilder 
	def AddVersion version, ns, versionId='', isLegacy=0, *a
	end

	def AddVersionParent version, parent, *a
	end

	def CreateDataType vmodlName, wsdlName, parentType, version, props
		update_vmodl2wsdl vmodlName, wsdlName
		DATA_TYPES[wsdlName] = {
			'wsdl_base' => parentType,
			'props' => props.map { |mName,mType,mVersion,mFoo|
				{
					'name' => mName,
					'wsdl_type' => mType,
				}
			}
		}
	end

	def CreateManagedType vmodlName, wsdlName, parentType, version, props, methods
		update_vmodl2wsdl vmodlName, wsdlName
		MANAGED_TYPES[wsdlName] = {
			'wsdl_base' => parentType,
			'props' => props.map do |mName,mType,mVersion,mFoo|
				{
					'name' => mName,
					'wsdl_type' => mType,
				}
			end,
			'methods' => Hash[methods.map do |mName,mWsdlName,mVersion,mParams,mResult|
				[mWsdlName, {
					'params' => mParams.map do |pName, pType, pVersion, pFoo|
						{
							'name' => pName,
							'wsdl_type' => pType,
						}
					end,
					'result' => (mResult != 'void') && {
						'wsdl_type' => mResult,
					} || nil
				}]
			end]
		}
	end

	def CreateEnumType vmodlName, wsdlName, version, values
		update_vmodl2wsdl vmodlName, wsdlName
		ENUM_TYPES[wsdlName] = {
			'values' => values,
		}
	end

	private

	def update_vmodl2wsdl vmodl, wsdl
		VMODL2WSDL[vmodl] = wsdl
		VMODL2WSDL[vmodl + '[]'] = 'ArrayOf' + wsdl
	end

	def decode_property_flags x
		[].tap do |a|
			a << 'link' if x & 1 != 0
			a << 'linkable' if x & 2 != 0
			a << 'optional' if x & 4 != 0
		end
	end
end

builder = ModelBuilder.new

PYTHON_MODELS.each do |e|
	path = "#{PYVMOMI}/#{e}.py"
	code = File.open(path, 'r') do |f|
		f.readline
		f.readline
		data = f.read
		data.gsub!(/^(\w+)\((.*)\)$/) { "#{$1}(#{$2.tr '()', '[]'})" }
		data
	end
	builder.instance_eval code, __FILE__, __LINE__
end

require 'set'
builtin = %w(DataObject ManagedObject MethodFault MethodName PropertyPath RuntimeFault TypeName)
builtin_array = builtin.map { |x| "ArrayOf#{x}" }
primitives = %w(string int short long byte boolean float double anyType dateTime)
primitive_array = %w(ArrayOfString ArrayOfInt ArrayOfShort ArrayOfLong ArrayOfByte ArrayOfFloat ArrayOfDOuble ArrayOfAnyType ArrayOfDateTime ArrayOfBoolean)
valid_types = Set.new(ENUM_TYPES.keys + DATA_TYPES.keys + MANAGED_TYPES.keys + primitives + builtin + builtin_array + primitive_array)
(ENUM_TYPES.keys+DATA_TYPES.keys+MANAGED_TYPES.keys).each { |k| valid_types << "ArrayOf#{k}" }

check = lambda { |x| fail "missing #{x}" unless valid_types.member?(x) }
munge_fault = lambda { |x| x['wsdl_type'] = 'LocalizedMethodFault' if x['wsdl_type'] == 'MethodFault' }

DATA_TYPES.each do |k,t|
	#t['wsdl_base'] = VMODL2WSDL[t['vmodl_base']]
	check[t['wsdl_base']]
	t['props'].each do |x|
		#x['wsdl_type'] = VMODL2WSDL[x['vmodl_type']]
		check[x['wsdl_type']]
		munge_fault[x]
	end
end

MANAGED_TYPES.each do |k,t|
	#t['wsdl_base'] = VMODL2WSDL[t['vmodl_base']]
	check[t['wsdl_base']]
	t['props'].each do |x|
		#x['wsdl_type'] = VMODL2WSDL[x['vmodl_type']]
		check[x['wsdl_type']]
		munge_fault[x]
	end
	t['methods'].each do |mName,x|
		if y = x['result']
			#y['wsdl_type'] = VMODL2WSDL[y['vmodl_type']]
			check[y['wsdl_type']]
			munge_fault[y]
		end
		x['params'].each do |r|
			#r['wsdl_type'] = VMODL2WSDL[r['vmodl_type']]
			check[r['wsdl_type']]
			munge_fault[r]
		end
	end
end

puts YAML.dump('data' => DATA_TYPES,
               'managed' => MANAGED_TYPES,
               'enum' => ENUM_TYPES)

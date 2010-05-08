#!/usr/bin/env ruby
require 'pp'
require 'date'
require 'ostruct'
require 'json'
require 'yaml'

PYVMOMI='/mts/home5/rlane/dbc/1/bora/build/build/vmodl/obj/generic/pyVmomi'
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
			'vmodl_base' => parentType,
			'props' => props.map { |mName,mType,mVersion,mFoo|
				{
					'name' => mName,
					'vmodl_type' => mType,
				}
			}
		}
	end

	def CreateManagedType vmodlName, wsdlName, parentType, version, props, methods
		update_vmodl2wsdl vmodlName, wsdlName
		MANAGED_TYPES[wsdlName] = {
			'vmodl_base' => parentType,
			'props' => props.map do |mName,mType,mVersion,mFoo|
				{
					'name' => mName,
					'vmodl_type' => mType,
				}
			end,
			'methods' => Hash[methods.map do |mName,mWsdlName,mVersion,mParams,mResult|
				[mWsdlName, {
					'params' => mParams.map do |pName, pType, pVersion, pFoo|
						{
							'name' => pName,
							'vmodl_type' => pType,
						}
					end,
					'result' => (mResult[1] != 'void') && {
						'flags' => decode_property_flags(mResult[0]),
						'vmodl_type' => mResult[1],
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

DATA_TYPES.each do |k,t|
	t['wsdl_base'] = VMODL2WSDL[t['vmodl_base']]
	t['props'].each do |x|
		x['wsdl_type'] = VMODL2WSDL[x['vmodl_type']]
	end
end

MANAGED_TYPES.each do |k,t|
	t['wsdl_base'] = VMODL2WSDL[t['vmodl_base']]
	t['props'].each do |x|
		x['wsdl_type'] = VMODL2WSDL[x['vmodl_type']]
	end
	t['methods'].each do |mName,x|
		if y = x['result']
			y['wsdl_type'] = VMODL2WSDL[y['vmodl_type']]
		end
		x['params'].each do |r|
			r['wsdl_type'] = VMODL2WSDL[r['vmodl_type']]
		end
	end
end

puts YAML.dump('data' => DATA_TYPES,
               'managed' => MANAGED_TYPES,
               'enum' => ENUM_TYPES)


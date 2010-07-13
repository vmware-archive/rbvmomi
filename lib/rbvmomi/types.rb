require 'gdbm'
require 'pp'
require 'set'

class Class
  def wsdl_name
    self.class.name
  end
end

module RbVmomi

module VIM

BUILTIN_TYPES = %w(ManagedObject TypeName PropertyPath ManagedObjectReference MethodName MethodFault LocalizedMethodFault)

# TODO make this a CDB
def self.load fn
  @db = GDBM.new fn, nil, GDBM::READER
  @vmodl = Hash.new { |h,k| if e = @db[k] then h[k] = Marshal.load(e) end }
  @typenames = Marshal.load(@db['_typenames']) + BUILTIN_TYPES
  Object.constants.select { |x| @typenames.member? x.to_s }.each { |x| load_type x }
end

def self.has_type? name
  @typenames.member? name.to_s
end

def self.type name
  if has_type? name
    const_get(name.to_sym)
  else
    fail "no such type #{name.inspect}"
  end
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
  desc = @vmodl[name] or fail "unknown VIM type #{name}"
  case desc['kind']
  when 'data' then make_data_type name, desc
  when 'managed' then make_managed_type name, desc
  when 'enum' then make_enum_type name, desc
  else fail desc.inspect
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
        define_method(sym) { _get_property sym }
        define_method(:"#{sym}=") { |x| _set_property sym, x }
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

  def _get_property sym
    fail 'unimplemented'
  end

  def _set_property sym, val
    fail 'unimplemented'
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
        define_method(sym) { |*args| _call sym, *args }
        define_method(:"#{sym}!") { |*args| _call sym, *args }
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
  attr_reader :props

  def initialize props={}
    @props = props
    @props.each do |k,v|
      fail "unexpected property name #{k}" unless self.class.find_prop_desc(k)
    end
  end

  def _get_property sym
    @props[sym]
  end

  def [] sym
    _get_property sym
  end

  def _set_property sym, val
    @props[sym] = val
  end

  def == o
    return false unless o.class == self.class
    keys = (props.keys + o.props.keys).uniq
    keys.all? { |k| props[k] == o.props[k] }
  end

  def hash
    props.hash
  end

  def pretty_print q
    q.text self.class.name
    q.group 2 do
      q.text '('
      q.breakable
      props = @props.sort_by { |k,v| k.to_s }
      q.seplist props, nil, :each do |k, v|
        q.group do
          q.text k.to_s
          q.text ': '
          q.pp v
        end
      end
    end
    q.breakable
    q.text ')'
  end

  initialize
end

class ManagedObject < ObjectWithMethods
  def initialize soap, ref
    super()
    @soap = soap
    @ref = ref
  end

  def _ref
    @ref
  end

  def _get_property sym
    ret = @soap.propertyCollector.RetrieveProperties(:specSet => [{
      :propSet => [{ :type => self.class.wsdl_name, :pathSet => [sym.to_s] }],
      :objectSet => [{ :obj => self }],
    }])[0]

    if ret.propSet.empty?
      fail if ret.missingSet.empty?
      raise ret.missingSet[0].fault
    else
      ret.propSet[0].val
    end
  end

  def _set_property sym, val
    fail 'unimplemented'
  end

  def _call method, o={}
    fail unless o.is_a? Hash
    desc = self.class.full_methods_desc[method.to_s] or fail "unknown method"
    @soap.call method, desc, {'_this' => self}.merge(o)
  end

  def to_s
    "#{self.class.wsdl_name}(#{@ref.inspect})"
  end

  def pretty_print pp
    pp.text to_s
  end

  def [] k
    _get_property k
  end

  def == x
    x.class == self.class and x._ref == @ref
  end

  alias eql? ==

  def hash
    [self.class, @ref].hash
  end

  initialize 'ManagedObject'
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
  initialize 'MethodFault', [
    { 'name' => 'faultCause', 'wsdl_type' => 'LocalizedMethodFault' },
    { 'name' => 'faultMessage', 'wsdl_type' => 'LocalizableMessage[]' },
  ]
end

class LocalizedMethodFault < DataObject
  initialize 'LocalizedMethodFault', [
    { 'name' => 'fault', 'wsdl_type' => 'MethodFault' },
    { 'name' => 'localizedMessage', 'wsdl_type' => 'xsd:string' },
  ]

  def exception
    RbVmomi.fault self.localizedMessage, self.fault
  end
end

class RuntimeFault < MethodFault
  initialize
end

class MethodName < String
  def self.wsdl_name; 'MethodName' end
end

class PropertyPath < String
  def self.wsdl_name; 'PropertyPath' end
end

class TypeName < String
  def self.wsdl_name; 'TypeName' end
end

class ManagedObjectReference
  def self.wsdl_name; 'ManagedObjectReference' end
end

end

end

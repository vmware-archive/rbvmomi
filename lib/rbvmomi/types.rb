require 'yaml'
require 'pp'
require 'set'

module RbVmomi

module VIM

def self.load fn
  @vmodl = YAML.load_file(fn)
  @typenames = @vmodl.map { |x,v| v.keys }.flatten + %w(ManagedObject TypeName PropertyPath)
  Object.constants.select { |x| @typenames.member? x.to_s }.each { |x| load_type x }
end

def self.type name
  if @typenames.member? name.to_s
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
        define_method(sym) { _get_property sym }
        define_method(:"#{sym}=") { |x| _set_propery sym, x }
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
    property sym.to_s
  end

  def _set_property sym, val
    fail 'unimplemented'
  end

  def call method, o={}
    fail unless o.is_a? Hash
    desc = self.class.full_methods_desc[method.to_s] or fail "unknown method"
    @soap.call method, desc, {'_this' => self}.merge(o)
  end

  def method_missing sym, *args, &b
    if sym.to_s =~ /!$/
      call $`.to_sym, *args, &b
    else
      property sym.to_s
    end
  end

  def to_s
    "MoRef(#{self.class.wsdl_name}, #{@ref})"
  end

  def pretty_print pp
    pp.text to_s
  end

  def property key
    @soap.propertyCollector.RetrieveProperties!(:specSet => [{
      :propSet => [{ :type => self.class.wsdl_name, :pathSet => [key] }],
      :objectSet => [{ :obj => self }],
    }])[:propSet][:val]
  end

  def wait
    filter = @soap.propertyCollector.CreateFilter! :spec => {
      :propSet => [{ :type => self.class.wsdl_name, :all => true }],
      :objectSet => [{ :obj => self }],
    }, :partialUpdates => false
    result = @soap.propertyCollector.WaitForUpdates!
    filter.DestroyPropertyFilter!
    changes = result.filterSets[0].objectSets[0].changeSets
    NiceHash[changes.map { |h| [h[:name].to_sym, h[:val]] }]
  end

  def wait_until &b
    loop do
      props = wait
      return props if b.call props
    end
  end

  def wait_task
    props = wait_until { |x| %w(success error).member? x[:info][:state] }
    case props[:info][:state]
    when 'success'
      props[:info][:result]
    when 'error'
      fail "task #{props[:info][:key]} failed: #{props[:info][:error][:localizedMessage]}"
    end
  end

  def [] k
    property k.to_s
  end

  def == x
    x.class == self.class and x._ref == @ref
  end

  def hash
    [type, value].hash
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
  def self.wsdl_name; 'MethodName' end
end

class PropertyPath < String
  def self.wsdl_name; 'PropertyPath' end
end

class TypeName < String
  def self.wsdl_name; 'TypeName' end
end

end

end

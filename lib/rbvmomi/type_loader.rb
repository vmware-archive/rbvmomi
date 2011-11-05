# Copyright (c) 2010 VMware, Inc.  All Rights Reserved.
require 'set'
require 'monitor'

module RbVmomi

class TypeLoader
  def initialize fn, extension_dirs, namespace
    @extension_dirs = extension_dirs
    @namespace = namespace
    @lock = Monitor.new
    @db = {}
    @id2wsdl = {}
    @loaded = {}
    add_types Hash[BasicTypes::BUILTIN.map { |k| [k,nil] }]
    vmodl_database = File.open(fn, 'r') { |io| Marshal.load io }
    vmodl_database.reject! { |k,v| k =~ /^_/ }
    add_types vmodl_database
    preload
  end

  def preload
    names = (@namespace.constants + Object.constants).map(&:to_s).uniq.
                                                      select { |x| has? x }
    names.each { |x| get(x) }
  end

  def has? name
    fail unless name.is_a? String
    @db.member?(name) or BasicTypes::BUILTIN.member?(name)
  end

  def get name
    fail unless name.is_a? String
    return @loaded[name] if @loaded.member? name
    @lock.synchronize do
      return @loaded[name] if @loaded.member? name
      klass = make_type(name)
      @namespace.const_set name, klass
      load_extension name
      @loaded[name] = klass
    end
  end

  def add_types types
    @lock.synchronize do
      @db.merge! types
    end
  end

  def typenames
    @db.keys
  end

  private

  def load_extension name
    @extension_dirs.map { |x| File.join(x, "#{name}.rb") }.
                    select { |x| File.exists? x }.
                    each { |x| load x }
  end

  def make_type name
    name = name.to_s
    return BasicTypes.const_get(name) if BasicTypes::BUILTIN.member? name
    desc = @db[name] or fail "unknown VMODL type #{name}"
    case desc['kind']
    when 'data' then make_data_type name, desc
    when 'managed' then make_managed_type name, desc
    when 'enum' then make_enum_type name, desc
    else fail desc.inspect
    end
  end

  def make_data_type name, desc
    superclass = get desc['wsdl_base']
    Class.new(superclass).tap do |klass|
      klass.init name, desc['props']
    end
  end

  def make_managed_type name, desc
    superclass = get desc['wsdl_base']
    Class.new(superclass).tap do |klass|
      klass.init name, desc['props'], desc['methods']
    end
  end

  def make_enum_type name, desc
    Class.new(BasicTypes::Enum).tap do |klass|
      klass.init name, desc['values']
    end
  end
end

end

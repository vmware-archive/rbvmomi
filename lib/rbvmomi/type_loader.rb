# Copyright (c) 2010 VMware, Inc.  All Rights Reserved.
require 'set'
require 'monitor'

module RbVmomi

class TypeLoader
  def initialize target, fn
    @target = target
    @lock = Monitor.new
    @db = {}
    @id2wsdl = {}
    add_types Hash[BasicTypes::BUILTIN.map { |k| [k,nil] }]
    vmodl_database = File.open(fn, 'r') { |io| Marshal.load io }
    vmodl_database.reject! { |k,v| k =~ /^_/ }
    add_types vmodl_database
  end

  def init
    @target.constants.select { |x| has_type? x.to_s }.each { |x| load_type x.to_s }
    BasicTypes::BUILTIN.each do |x|
      @target.const_set x, BasicTypes.const_get(x)
      load_extension x
    end
    Object.constants.map(&:to_s).select { |x| has_type? x }.each do |x|
      load_type x
    end
  end

  def has_type? name
    fail unless name.is_a? String
    @db.member? name
  end

  def load_type name
    fail unless name.is_a? String
    @lock.synchronize do
      return nil if @target.const_defined? name and not Object.const_defined? name
      @target.const_set name, make_type(name)
      load_extension name
    end
    nil
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
    dirs = @target.extension_dirs
    dirs.map { |x| File.join(x, "#{name}.rb") }.
         select { |x| File.exists? x }.
         each { |x| load x }
  end

  def make_type name
    name = name.to_s
    fail if BasicTypes::BUILTIN.member? name
    desc = @db[name] or fail "unknown VMODL type #{name}"
    case desc['kind']
    when 'data' then make_data_type name, desc
    when 'managed' then make_managed_type name, desc
    when 'enum' then make_enum_type name, desc
    else fail desc.inspect
    end
  end

  def make_data_type name, desc
    superclass = @target.const_get desc['wsdl_base']
    Class.new(superclass).tap do |klass|
      klass.init name, desc['props']
    end
  end

  def make_managed_type name, desc
    superclass = @target.const_get desc['wsdl_base']
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

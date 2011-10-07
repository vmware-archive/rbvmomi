module RbVmomi

class VIM::HostSystem
  def esxcli
    if _connection.serviceContent.about.apiType != 'HostAgent'
      fail "esxcli is only supported when connecting directly to a host"
    end
    @esxcli ||= VIM::EsxcliNamespace.root(self)
  end

  def dtm
    @dtm ||= VIM::InternalDynamicTypeManager(_connection, 'ha-dynamic-type-manager')
  end

  def dti
    @dti ||= dtm.DynamicTypeMgrQueryTypeInfo
  end
end

class VIM::EsxcliNamespace
  attr_reader :conn, :namespaces, :commands, :inst

  def self.root host
    conn = host._connection
    ns = VIM::EsxcliNamespace.new nil, nil, nil
    instances = host.dtm.DynamicTypeMgrQueryMoInstances
    path2obj = {}
    type_hash = host.dti.toRbvmomiTypeHash
    conn.class.loader.add_types type_hash
    vmodl2info = Hash[host.dti.managedTypeInfo.map { |x| [x.name,x] }]
    instances.sort_by(&:moType).each do |inst|
      path = inst.moType.split('.')
      next unless path[0..1] == ['vim', 'EsxCLI']
      ns.add path[2..-1], conn, inst, vmodl2info[inst.moType]
    end
    ns
  end

  def initialize conn, inst, type
    @conn = conn
    @namespaces = {}
    @commands = {}
    @type = type
    @inst = inst
    if inst
      @cli_info_fetcher = VIM::VimCLIInfo.new(conn, 'ha-dynamic-type-manager-local-cli-cliinfo')
      @cli_info = nil
      @obj = conn.type(type.wsdlName).new(conn, inst.id)
      type.method.each do |m|
        @commands[m.name] = m
      end
    else
      @obj = nil
    end
  end

  def cli_info
    return nil unless @inst
    @cli_info ||= @cli_info_fetcher.VimCLIInfoFetchCLIInfo(:typeName => @inst.moType)
  end

  def add path, conn, inst, type
    child = path.shift
    if path.empty?
      fail if @namespaces.member? child
      @namespaces[child] = VIM::EsxcliNamespace.new conn, inst, type
    else
      @namespaces[child] ||= VIM::EsxcliNamespace.new nil, nil, nil
      @namespaces[child].add path, conn, inst, type
    end
  end

  def call name, args={}
    m = @commands[name]
    raise NoMethodError.new(name) unless m
    @obj._call m.wsdlName, args
  end

  def method_missing name, *args
    name = name.to_s
    if @namespaces.member? name and args.empty?
      @namespaces[name]
    elsif @commands.member? name
      call name, *args
    else
      raise NoMethodError
    end
  end

  def pretty_print q
    q.text "Namespaces: "
    @namespaces.keys.pretty_print q
    q.breakable
    q.text "Commands: "
    @commands.keys.pretty_print q
  end
end

end

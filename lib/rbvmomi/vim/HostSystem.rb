module RbVmomi

class VIM::HostSystem
  def esxcli
    if _connection.serviceContent.about.apiType != 'HostAgent'
      fail "esxcli is only supported when connecting directly to a host"
    end
    @cached_esxcli ||= VIM::EsxcliNamespace.root(self)
  end

  def dtm
    @cached_dtm ||= RetrieveDynamicTypeManager()
  end

  def dti
    @cached_dti ||= dtm.DynamicTypeMgrQueryTypeInfo
  end

  def cli_info_fetcher
    # XXX there can be more than one
    @cached_cli_info_fetcher ||=
      dtm.DynamicTypeMgrQueryMoInstances.find { |x| x.moType == 'vim.CLIInfo' }
  end

  def mme
    @cached_mme ||= RetrieveManagedMethodExecuter()
  end
end

class VIM::EsxcliNamespace
  ESXCLI_PREFIX = 'vim.EsxCLI.'

  attr_reader :name, :parent, :host, :type, :instance, :type_info, :namespaces, :commands

  def self.root host
    type_hash = host.dti.toRbvmomiTypeHash
    VIM.loader.add_types type_hash
    all_instances = host.dtm.DynamicTypeMgrQueryMoInstances
    instances = Hash[all_instances.select { |x| x.moType.start_with? ESXCLI_PREFIX }.
                                   map { |x| [x.moType,x.id] }]
    type_infos = Hash[host.dti.managedTypeInfo.map { |x| [x.name,x] }]
    new('root', nil, host).tap do |root|
      instances.each do |type,instance|
        path = type.split('.')[2..-1]
        ns = path.inject(root) { |b,v| b.namespaces[v] }
        ns.realize type, instance, type_infos[type]
      end
    end
  end

  def initialize name, parent, host
    @name = name
    @parent = parent
    @host = host
    @type = nil
    @instance = nil
    @type_info = nil
    @namespaces = Hash.new { |h,k| h[k] = self.class.new k, self, host }
    @commands = {}
    @cached_cli_info = nil
  end

  def realize type, instance, type_info
    fail if @type or @instance
    @type = type
    @instance = instance
    @type_info = type_info
    @type_info.method.each do |method_type_info|
      name = method_type_info.name
      @commands[name] = VIM::EsxcliCommand.new self, method_type_info
    end
  end

  def type_name
    if @type then @type
    elsif @parent then "#{@parent.type_name}.#{@name}"
    else 'vim.EsxCLI'
    end
  end

  def cli_info
    @cached_cli_info ||= @host.cli_info_fetcher.VimCLIInfoFetchCLIInfo(typeName: type_name)
  end

  def obj
    conn = @host._connection
    conn.type(@type_info.wsdlName).new(conn, @instance)
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
    q.text @name
    q.text ' '
    q.group 2 do
      q.text '{'
      q.breakable
      items = (@namespaces.values+@commands.values).sort_by(&:name)
      q.seplist items, nil, :each do |v|
        if v.is_a? VIM::EsxcliNamespace
          q.pp v
        else
          q.text v.name
        end
      end
    end
    q.breakable
    q.text '}'
  end
end

class VIM::EsxcliCommand
  attr_reader :ns, :type_info, :cli_info

  def initialize ns, type_info
    @ns = ns
    @type_info = type_info
    @cached_cli_info = nil
  end

  def cli_info
    @cached_cli_info ||= @ns.cli_info.method.find { |x| x.name == @type_info.name }
  end

  def call args={}
    @ns.obj._call @type_info.wsdlName, args
  end
end

end

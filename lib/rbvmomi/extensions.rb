module RbVmomi::VIM

class ManagedObject
  def wait *pathSet
    all = pathSet.empty?
    filter = @soap.propertyCollector.CreateFilter :spec => {
      :propSet => [{ :type => self.class.wsdl_name, :all => all, :pathSet => pathSet }],
      :objectSet => [{ :obj => self }],
    }, :partialUpdates => false
    result = @soap.propertyCollector.WaitForUpdates
    filter.DestroyPropertyFilter
    changes = result.filterSet[0].objectSet[0].changeSet
    changes.map { |h| [h.name.split('.').map(&:to_sym), h.val] }.each do |path,v|
      k = path.pop
      o = path.inject(self) { |b,k| b[k] }
      o._set_property k, v unless o == self
    end
    nil
  end

  def wait_until *pathSet, &b
    loop do
      wait *pathSet
      if x = b.call
        return x
      end
    end
  end
end

Task
class Task
  def wait_for_completion
    wait_until('info.state') { %w(success error).member? info.state }
    case info.state
    when 'success'
      info.result
    when 'error'
      raise info.error
    end
  end
end

Folder
class Folder
  def find name, type=Object
    childEntity.grep(type).find { |x| x.name == name }
  end

  def traverse! path, type=Object
    traverse path, type, true
  end

  def traverse path, type=Object, create=false
    es = path.split('/').reject(&:empty?)
    return self if es.empty?
    final = es.pop

    p = es.inject(self) do |f,e|
      f.find(e, Folder) || (create && f.CreateFolder(name: e)) || return
    end

    if x = p.find(final, type)
      x
    elsif create and type == Folder
      p.CreateFolder(name: final)
    else
      nil
    end
  end

  def children
    childEntity
  end

  def ls
    Hash[children.map { |x| [x.name, x] }]
  end
end

Datastore
class Datastore
  def datacenter
    return @datacenter if @datacenter
    x = parent
    while not x.is_a? Datacenter
      x = x.parent
    end
    fail unless x.is_a? Datacenter
    @datacenter = x
  end

  def mkuripath path
    "/folder/#{URI.escape path}?dcPath=#{URI.escape datacenter.name}&dsName=#{URI.escape name}"
  end

  def exists? path
    req = Net::HTTP::Head.new mkuripath(path)
    req.initialize_http_header 'cookie' => @soap.cookie
    resp = @soap.http.request req
    case resp
    when Net::HTTPSuccess
      true
    when Net::HTTPNotFound
      false
    else
      fail resp.inspect
    end
  end

  def get path, io
    req = Net::HTTP::Get.new mkuripath(path)
    req.initialize_http_header 'cookie' => @soap.cookie
    resp = @soap.http.request(req)
    case resp
    when Net::HTTPSuccess
      io.write resp.body if resp.is_a? Net::HTTPSuccess
      true
    else
      fail resp.inspect
    end
  end

  def upload remote_path, local_path
    url = "https://#{@soap.http.address}:#{@soap.http.port}#{mkuripath(remote_path)}"
    pid = spawn "curl", "-k", '--noproxy', '*',
                "-T", local_path,
                "-b", @soap.cookie,
                url,
                out: '/dev/null'
    Process.waitpid(pid, 0)
    fail "upload failed" unless $?.success?
  end
end

ServiceInstance
class ServiceInstance
  def find_datacenter path=nil
    if path
      content.rootFolder.traverse path, VIM::Datacenter
    else
      content.rootFolder.childEntity.grep(VIM::Datacenter).first
    end
  end
end

Datacenter
class Datacenter
  def find_compute_resource path=nil
    if path
      hostFolder.traverse path, VIM::ComputeResource
    else
      hostFolder.childEntity.grep(VIM::ComputeResource).first
    end
  end

  def find_datastore name
    datastore.find { |x| x.name == name }
  end

  def find_vm folder_path, name
    vmFolder.traverse "#{folder_path}/#{name}", VIM::VirtualMachine
  end
end

end

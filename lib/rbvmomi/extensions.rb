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
      fail "task #{info.key} failed: #{info.error.localizedMessage}"
    end
  end
end

Folder
class Folder
  def find name, type=Object
    childEntity.grep(type).find { |x| x.name == name }
  end

  def traverse path, type=Object
    es = path.split('/')
    return self if es.empty?
    final = es.pop
    es.inject(self) do |f,e|
      f.find e, Folder or return nil
    end.find final, type
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
    "/folder/#{URI.escape path}?dcName=#{URI.escape datacenter.name}&dsName=#{URI.escape name}"
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

  def put path, io
    s = TCPSocket.new @soap.http.address, @soap.http.port
    if @soap.http.use_ssl?
      s = OpenSSL::SSL::SSLSocket.new s
      s.sync_close = true
      s.connect
    end

    s.write <<-EOS
PUT #{URI.escape mkuripath(path)} HTTP/1.1\r
Cookie: #{@soap.cookie}\r
Connection: close\r
Host: #{@soap.http.address}\r
Transfer-Encoding: chunked\r
\r
    EOS

    while chunk = (io.readpartial(65536) rescue nil)
      s.write "#{chunk.size.to_s(16)}\r\n#{chunk}\r\n"
      yield chunk.size
    end

    s.write "0\r\n\r\n"
  end

=begin
  def put path, io
    req = Net::HTTP::Put.new mkuripath(path)
    req.initialize_http_header 'cookie' => @soap.cookie,
                               'Transfer-Encoding' => 'chunked',
                               'Content-Type' => 'application/octet-stream'
    req.body_stream = io
    @soap.http.request req
    case resp
    when Net::HTTPSuccess
      true
    else
      fail resp.inspect
    end
  end
=end
end

end

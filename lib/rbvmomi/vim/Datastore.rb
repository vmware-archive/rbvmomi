class RbVmomi::VIM::Datastore
  CURLBIN = ENV['CURL'] || "curl"

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

  def download remote_path, local_path
    url = "http#{@soap.http.use_ssl? ? 's' : ''}://#{@soap.http.address}:#{@soap.http.port}#{mkuripath(remote_path)}"
    pid = spawn CURLBIN, "-k", '--noproxy', '*', '-f',
                "-o", local_path,
                "-b", @soap.cookie,
                url,
                out: '/dev/null'
    Process.waitpid(pid, 0)
    fail "download failed" unless $?.success?
  end

  def upload remote_path, local_path
    url = "http#{@soap.http.use_ssl? ? 's' : ''}://#{@soap.http.address}:#{@soap.http.port}#{mkuripath(remote_path)}"
    pid = spawn CURLBIN, "-k", '--noproxy', '*', '-f',
                "-T", local_path,
                "-b", @soap.cookie,
                url,
                out: '/dev/null'
    Process.waitpid(pid, 0)
    fail "upload failed" unless $?.success?
  end
end

# frozen_string_literal: true
# Copyright (c) 2011-2017 VMware, Inc.  All Rights Reserved.
# SPDX-License-Identifier: MIT

# @note +download+ and +upload+ require +curl+. If +curl+ is not in your +PATH+
#       then set the +CURL+ environment variable to point to it.
# @todo Use an HTTP library instead of executing +curl+.
class RbVmomi::VIM::Datastore
  CURLBIN = ENV['CURL'] || 'curl' #@private

  # Check whether a file exists on this datastore.
  # @param path [String] Path on the datastore.
  def exists? path
    req = Net::HTTP::Head.new mkuripath(path)
    req.initialize_http_header 'cookie' => _connection.cookie
    resp = _connection.http.request req
    case resp
    when Net::HTTPSuccess
      true
    when Net::HTTPNotFound
      false
    else
      raise resp.inspect
    end
  end

  # Download a file from this datastore.
  # @param remote_path [String] Source path on the datastore.
  # @param local_path [String] Destination path on the local machine.
  # @return [void]
  def download remote_path, local_path
    url = "http#{_connection.http.use_ssl? ? 's' : ''}://#{_connection.http.address}:#{_connection.http.port}#{mkuripath(remote_path)}"
    pid = spawn CURLBIN, '-k', '--noproxy', '*', '-f',
                '-o', local_path,
                '-b', _connection.cookie,
                url,
                out: '/dev/null'
    Process.waitpid(pid, 0)
    raise 'download failed' unless $?.success?
  end

  # Upload a file to this datastore.
  # @param remote_path [String] Destination path on the datastore.
  # @param local_path [String] Source path on the local machine.
  # @return [void]
  def upload remote_path, local_path
    url = "http#{_connection.http.use_ssl? ? 's' : ''}://#{_connection.http.address}:#{_connection.http.port}#{mkuripath(remote_path)}"
    pid = spawn CURLBIN, '-k', '--noproxy', '*', '-f',
                '-T', local_path,
                '-b', _connection.cookie,
                url,
                out: '/dev/null'
    Process.waitpid(pid, 0)
    raise 'upload failed' unless $?.success?
  end

  private

  def datacenter
    return @datacenter if @datacenter
    x = parent
    while not x.is_a? RbVmomi::VIM::Datacenter
      x = x.parent
    end
    raise unless x.is_a? RbVmomi::VIM::Datacenter
    @datacenter = x
  end

  def mkuripath path
    datacenter_path_str = datacenter.path[1..-1].map{|elem| elem[1]}.join('/')
    "/folder/#{URI.encode_www_form_component path}?dcPath=#{URI.encode_www_form_component datacenter_path_str }&dsName=#{URI.encode_www_form_component name}"
  end
end

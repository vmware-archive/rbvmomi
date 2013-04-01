class RbVmomi::VIM::OvfManager

  # Deploy an OVF.
  #
  # @param [Hash] opts The options hash.
  # @option opts [String]             :uri Location of the OVF.
  # @option opts [String]             :vmName Name of the new VM.
  # @option opts [VIM::Folder]        :vmFolder Folder to place the VM in.
  # @option opts [VIM::HostSystem]    :host Host to use.
  # @option opts [VIM::ResourcePool]  :resourcePool Resource pool to use.
  # @option opts [VIM::Datastore]     :datastore Datastore to use.
  # @option opts [String]             :diskProvisioning (thin) Disk provisioning mode.
  # @option opts [Hash]               :networkMappings Network mappings.
  # @option opts [Hash]               :propertyMappings Property mappings.
  def deployOVF opts
    opts = { :networkMappings => {},
             :propertyMappings => {},
             :diskProvisioning => :thin }.merge opts

    %w(uri vmName vmFolder host resourcePool datastore).each do |k|
      fail "parameter #{k} required" unless opts[k.to_sym]
    end

    ovfImportSpec = RbVmomi::VIM::OvfCreateImportSpecParams(
      :hostSystem => opts[:host],
      :locale => "US",
      :entityName => opts[:vmName],
      :deploymentOption => "",
      :networkMapping => opts[:networkMappings].map{|from, to| RbVmomi::VIM::OvfNetworkMapping(:name => from, :network => to)},
      :propertyMapping => opts[:propertyMappings].to_a,
      :diskProvisioning => opts[:diskProvisioning]
    )

    result = CreateImportSpec(
      :ovfDescriptor => open(opts[:uri]).read,
      :resourcePool => opts[:resourcePool],
      :datastore => opts[:datastore],
      :cisp => ovfImportSpec
    )

    raise result.error[0].localizedMessage if result.error && !result.error.empty?

    if result.warning
      result.warning.each{|x| puts "OVF Warning: #{x.localizedMessage.chomp}" }
    end

    nfcLease = opts[:resourcePool].ImportVApp(:spec => result.importSpec,
                                              :folder => opts[:vmFolder],
                                              :host => opts[:host])

    nfcLease.wait_until(:state) { nfcLease.state != "initializing" }
    raise nfcLease.error if nfcLease.state == "error"
    begin
      nfcLease.HttpNfcLeaseProgress(:percent => 5)
      progress = 5.0
      result.fileItem.each do |fileItem|
        deviceUrl = nfcLease.info.deviceUrl.find{|x| x.importKey == fileItem.deviceId}
        if !deviceUrl
          raise "Couldn't find deviceURL for device '#{fileItem.deviceId}'"
        end

        keepAliveThread = Thread.new do
          while true
            sleep 2 * 60
            nfcLease.HttpNfcLeaseProgress(:percent => progress.to_i)
          end
        end

        href = deviceUrl.url.gsub("*", opts[:host].config.network.vnic[0].spec.ip.ipAddress)

        # fileItem.create actually means that the object has been already
        # created
        ovfFilename = opts[:uri].to_s
        file_body = file_body(ovfFilename, fileItem.path)

        unless fileItem.create
          Excon.post(URI::escape(href), :body => file_body)
        else
          Excon.put(URI::escape(href), :body => file_body)
        end

        keepAliveThread.kill
        keepAliveThread.join

        progress += (90.0 / result.fileItem.length)
        nfcLease.HttpNfcLeaseProgress(:percent => progress.to_i)
      end

      nfcLease.HttpNfcLeaseProgress(:percent => 100)
      vm = nfcLease.info.entity
      nfcLease.HttpNfcLeaseComplete
      vm
    end
  rescue Exception
    (nfcLease.HttpNfcLeaseAbort rescue nil) if nfcLease
    raise
  end

  def file_body(ovf_uri, path)
    require 'uri'
    uri = URI.parse(ovf_uri)
    if uri.scheme.nil?
      # local path
      File.open(File.expand_path(path, File.dirname(ovf_uri)))
    else
      # same hack that we had before
      tmp = ovf_uri.split(/\//)
      tmp.pop
      tmp << path
      tmp.join("/")

      Excon.get(tmp).body
    end
  end
end

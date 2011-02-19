class RbVmomi::VIM::ManagedObject
  def wait_until *pathSet, &b
    all = pathSet.empty?
    filter = @soap.propertyCollector.CreateFilter :spec => {
      :propSet => [{ :type => self.class.wsdl_name, :all => all, :pathSet => pathSet }],
      :objectSet => [{ :obj => self }],
    }, :partialUpdates => false
    ver = ''
    loop do
      result = @soap.propertyCollector.WaitForUpdates(version: ver)
      ver = result.version
      if x = b.call
        return x
      end
    end
  ensure
    filter.DestroyPropertyFilter if filter
  end

  def collect! *props
    spec = {
      objectSet: [{ obj: self }],
      propSet: [{
        pathSet: props,
        type: self.class.wsdl_name
      }]
    }
    @soap.propertyCollector.RetrieveProperties(specSet: [spec])[0].to_hash
  end

  def collect *props
    h = collect! *props
    a = props.map { |k| h[k.to_s] }
    if block_given?
      yield a
    else
      a
    end
  end
end

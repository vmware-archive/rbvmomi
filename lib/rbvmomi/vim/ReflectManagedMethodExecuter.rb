module RbVmomi

class VIM::ReflectManagedMethodExecuter
  def fetch moid, prop
    result = FetchSoap(:moid => moid, :version => 'urn:vim25/5.0', :prop => prop)
    xml = Nokogiri(result.response)
    _connection.xml2obj xml.root, nil
  end

  def execute moid, method, args
    soap_args = args.map do |k,v|
      puts "serializing #{k}"
      VIM::ReflectManagedMethodExecuterSoapArgument.new.tap do |soap_arg|
        soap_arg.name = k
        xml = Builder::XmlMarkup.new :indent => 0
        _connection.obj2xml xml, k, :anyType, false, v
        soap_arg.val = xml.target!
      end
    end
    result = ExecuteSoap(:moid => moid, :version => 'urn:vim25/5.0',
                         :method => method, :argument => soap_args)
  end
end

end


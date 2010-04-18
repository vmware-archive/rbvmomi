require 'rbvmomi'

fail "must set RBVMOMI_HOST" unless ENV['RBVMOMI_HOST']

soap = RbVmomi::Soap.new URI.parse("https://#{ENV['RBVMOMI_HOST']}/sdk")
soap.debug = true

soap.call :RetrieveServiceContent do |xml|
  xml._this "ServiceInstance", :type => 'ServiceInstance'
end

soap.call :Login do |xml|
  xml._this "ha-sessionmgr", :type => "SessionManager"
  xml.userName "root"
  xml.password ""
end

soap.call :CurrentTime do |xml|
  xml._this "ServiceInstance", :type => 'ServiceInstance'
end

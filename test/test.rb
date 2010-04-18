require 'rbvmomi'
include RbVmomi

fail "must set RBVMOMI_HOST" unless ENV['RBVMOMI_HOST']

soap = Soap.new URI.parse("https://#{ENV['RBVMOMI_HOST']}/sdk")
soap.debug = true

si = MoRef.new(soap, 'ServiceInstance', 'ServiceInstance')
sm = MoRef.new(soap, 'SessionManager', 'ha-sessionmgr')

si.call :RetrieveServiceContent

sm.call :Login do |xml|
  xml.userName "root"
  xml.password ""
end

si.call :CurrentTime

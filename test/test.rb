require 'rbvmomi'
include RbVmomi

fail "must set RBVMOMI_HOST" unless ENV['RBVMOMI_HOST']

soap = Soap.new URI.parse("https://#{ENV['RBVMOMI_HOST']}/sdk")
soap.debug = true

si = soap.serviceInstance
sm = si.RetrieveServiceContent['sessionManager']
sm.Login :userName => 'root', :password => ''

pp si.CurrentTime

rootFolder = si.RetrieveServiceContent['rootFolder']
pp rootFolder

pc = si.RetrieveServiceContent['propertyCollector']
ret = pc.RetrieveProperties :specSet => {
  :propSet => { :type => 'Folder', :all => true },
  :objectSet => { :obj => rootFolder },
}
pp ret

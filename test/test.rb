require 'rbvmomi'
include RbVmomi

fail "must set RBVMOMI_HOST" unless ENV['RBVMOMI_HOST']

soap = Soap.new URI.parse("https://#{ENV['RBVMOMI_HOST']}/sdk")
soap.debug = false

si = soap.serviceInstance
sm = si.RetrieveServiceContent['sessionManager']
sm.Login :userName => 'root', :password => ''

rootFolder = si.RetrieveServiceContent['rootFolder']

dc = rootFolder[:childEntity].first
vmFolder = dc[:vmFolder]
vms = vmFolder[:childEntity]
pp vms

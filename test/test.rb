require 'rbvmomi'
include RbVmomi

fail "must set RBVMOMI_HOST" unless ENV['RBVMOMI_HOST']

soap = Soap.new URI.parse("https://#{ENV['RBVMOMI_HOST']}/sdk")
soap.debug = true

si = soap.serviceInstance
sm = si.RetrieveServiceContent['sessionManager']
sm.Login :userName => 'root', :password => ''

rootFolder = si.RetrieveServiceContent['rootFolder']

dc = rootFolder[:childEntity].first
vmFolder = dc[:vmFolder]
vms = vmFolder[:childEntity]
pp vms
hosts = dc[:hostFolder][:childEntity]
pp hosts
rp = hosts.first

vm_cfg = {
  name: 'vm',
  guestId: 'otherGuest64',
  files: { vmPathName: '[datastore1]' },
  numCPUs: 2,
  memoryMB: 3072,
  deviceChange: [
    {
      operation: :add,
      device: VIM.VirtualLsiLogicController(
        key: XSD.int(1000),
        busNumber: XSD.int(0),
        sharedBus: :noSharing,
      )
    }, {
      operation: :add,
      fileOperation: :create,
      device: VIM.VirtualDisk(
        key: XSD.int(0),
        backing: VIM.VirtualDiskFlatVer2BackingInfo(
          fileName: '[datastore1]',
          diskMode: :persistent,
          thinProvisioned: true,
        ),
        controllerKey: 1000,
        unitNumber: 0,
        capacityInKB: XSD.long(4000000),
      )
    }, {
      operation: :add,
      device: VIM.VirtualE1000(
        key: XSD.int(0),
        deviceInfo: {
          label: 'Network Adapter 1',
          summary: 'VM Network',
        },
        backing: VIM.VirtualEthernetCardNetworkBackingInfo(
          deviceName: 'VM Network',
        ),
        addressType: 'generated'
      )
    }
  ],
  extraConfig: [
    {
      key: 'bios.bootOrder',
      value: XSD.string('ethernet0')
    }
  ]
}

vmFolder.CreateVM_Task :config => vm_cfg, :pool => rp

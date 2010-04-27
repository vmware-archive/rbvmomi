#!/usr/bin/env ruby
require 'rbvmomi'
include RbVmomi

vim = RbVmomi.connect ENV['RBVMOMI_URI']

rootFolder = vim.serviceInstance.RetrieveServiceContent!.rootFolder

dc = rootFolder.childEntity.first
vmFolder = dc.vmFolder
vms = vmFolder.childEntity
hosts = dc.hostFolder.childEntity
rp = hosts.first.resourcePool

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
        key: 1000,
        busNumber: 0,
        sharedBus: :noSharing,
      )
    }, {
      operation: :add,
      fileOperation: :create,
      device: VIM.VirtualDisk(
        key: 0,
        backing: VIM.VirtualDiskFlatVer2BackingInfo(
          fileName: '[datastore1]',
          diskMode: :persistent,
          thinProvisioned: true,
        ),
        controllerKey: 1000,
        unitNumber: 0,
        capacityInKB: 4000000,
      )
    }, {
      operation: :add,
      device: VIM.VirtualE1000(
        key: 0,
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

N = 2
create_tasks = (0...N).map { vmFolder.CreateVM_Task!(:config => vm_cfg, :pool => rp) }
destroy_tasks = create_tasks.map { |x| x.wait_task.Destroy_Task! }
destroy_tasks.each { |x| x.wait_task }

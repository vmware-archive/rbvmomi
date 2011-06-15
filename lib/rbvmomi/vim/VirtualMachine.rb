class RbVmomi::VIM::VirtualMachine
  # Retrieve the MAC addresses for all virtual NICs.
  # @return [Hash] Keyed by device label.
  def macs
    Hash[self.config.hardware.device.grep(RbVmomi::VIM::VirtualEthernetCard).map { |x| [x.deviceInfo.label, x.macAddress] }]
  end
  
  # Retrieve all virtual disk devices.
  # @return [Array] Array of virtual disk devices.
  def disks
    self.config.hardware.device.grep(RbVmomi::VIM::VirtualDisk)
  end
end

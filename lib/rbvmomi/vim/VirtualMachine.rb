class RbVmomi::VIM::VirtualMachine
  def macs
    Hash[self.config.hardware.device.grep(VIM::VirtualEthernetCard).map { |x| [x.deviceInfo.label, x.macAddress] }]
  end
end

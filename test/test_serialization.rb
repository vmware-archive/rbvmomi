require 'test/unit'
require 'rbvmomi'
include RbVmomi

class SerializationTest < Test::Unit::TestCase
  def check str, obj, type
    soap = RbVmomi::Soap.new({})
    xml = Builder::XmlMarkup.new :indent => 2
    soap.obj2xml(xml, 'root', type, false, obj)

    puts "expected:"
    puts str
    puts
    puts "got:"
    puts xml.target!
    puts

    assert_equal str, xml.target!
  end

  def test_moref
    check <<-EOS, VIM.Folder(nil, "ha-folder-host"), "Folder"
<root type="Folder">ha-folder-host</root>
    EOS
  end

  def test_config
    cfg = VIM.VirtualMachineConfigSpec(
      name: 'vm',
      files: { vmPathName: '[datastore1]' },
      guestId: 'otherGuest64',
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
        }, VIM.VirtualDeviceConfigSpec(
          operation: VIM.VirtualDeviceConfigSpecOperation(:add),
          fileOperation: VIM.VirtualDeviceConfigSpecFileOperation(:create),
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
        ), {
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
          value: 'ethernet0'
        }
      ]
    )
    check <<-EOS, cfg, "VirtualMachineConfigSpec"
<root xsi:type="VirtualMachineConfigSpec">
  <name>vm</name>
  <guestId>otherGuest64</guestId>
  <files xsi:type="VirtualMachineFileInfo">
    <vmPathName>[datastore1]</vmPathName>
  </files>
  <numCPUs>2</numCPUs>
  <memoryMB>3072</memoryMB>
  <deviceChange xsi:type="VirtualDeviceConfigSpec">
    <operation>add</operation>
    <device xsi:type="VirtualLsiLogicController">
      <key>1000</key>
      <busNumber>0</busNumber>
      <sharedBus>noSharing</sharedBus>
    </device>
  </deviceChange>
  <deviceChange xsi:type="VirtualDeviceConfigSpec">
    <operation>add</operation>
    <fileOperation>create</fileOperation>
    <device xsi:type="VirtualDisk">
      <key>0</key>
      <backing xsi:type="VirtualDiskFlatVer2BackingInfo">
        <fileName>[datastore1]</fileName>
        <diskMode>persistent</diskMode>
        <thinProvisioned>1</thinProvisioned>
      </backing>
      <controllerKey>1000</controllerKey>
      <unitNumber>0</unitNumber>
      <capacityInKB>4000000</capacityInKB>
    </device>
  </deviceChange>
  <deviceChange xsi:type="VirtualDeviceConfigSpec">
    <operation>add</operation>
    <device xsi:type="VirtualE1000">
      <key>0</key>
      <deviceInfo xsi:type="Description">
        <label>Network Adapter 1</label>
        <summary>VM Network</summary>
      </deviceInfo>
      <backing xsi:type="VirtualEthernetCardNetworkBackingInfo">
        <deviceName>VM Network</deviceName>
      </backing>
      <addressType>generated</addressType>
    </device>
  </deviceChange>
  <extraConfig xsi:type="OptionValue">
    <key>bios.bootOrder</key>
    <value xsi:type="xsd:string">ethernet0</value>
  </extraConfig>
</root>
    EOS
  end
end

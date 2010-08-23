require 'test/unit'
require 'rbvmomi'
include RbVmomi

class DeserializationTest < Test::Unit::TestCase
  def setup
    @soap = RbVmomi::Soap.new({})
  end

  def check str, expected, type
    got = @soap.xml2obj Nokogiri(str).root, type

    puts "expected:"
    pp expected
    puts
    puts "got:"
    pp got
    puts

    assert_equal expected, got
  end

  def test_moref
    check <<-EOS, VIM.Folder(nil, 'ha-folder-root'), 'Folder'
<root type="Folder">ha-folder-root</root>
    EOS

    check <<-EOS, VIM.Datacenter(nil, 'ha-datacenter'), 'ManagedObjectReference'
<ManagedObjectReference type="Datacenter" xsi:type="ManagedObjectReference">ha-datacenter</ManagedObjectReference>
    EOS
  end

  def test_dataobject
    obj = VIM.DatastoreSummary(
      capacity: 1000,
      accessible: true,
      datastore: VIM.Datastore(nil, "foo"),
      freeSpace: 31,
      multipleHostAccess: false,
      name: "baz",
      type: "VMFS",
      url: "http://foo/",
      dynamicProperty: []
    )

    check <<-EOS, obj, 'DatastoreSummary'
<root>
  <capacity>1000</capacity>
  <accessible>1</accessible>
  <datastore type="Datastore">foo</datastore>
  <freeSpace>31</freeSpace>
  <multipleHostAccess>false</multipleHostAccess>
  <name>baz</name>
  <type>VMFS</type>
  <url>http://foo/</url>
</root>
    EOS
  end

  def test_enum
    check <<-EOS, 'add', 'ConfigSpecOperation'
<root>add</root>
    EOS
  end

  def test_array
    obj = VIM.ObjectContent(
      obj: VIM.Folder(nil, 'ha-folder-root'),
      dynamicProperty: [],
      missingSet: [],
      propSet: [
        VIM.DynamicProperty(
          name: 'childEntity',
          val: [
            VIM.Datacenter(nil, 'ha-datacenter')
          ]
        )
      ]
    )

    check <<-EOS, obj, 'ObjectContent'
<root xmlns:xsi="#{RbVmomi::Soap::NS_XSI}">
   <obj type="Folder">ha-folder-root</obj>
   <propSet>
      <name>childEntity</name>
      <val xsi:type="ArrayOfManagedObjectReference">
         <ManagedObjectReference type="Datacenter" xsi:type="ManagedObjectReference">ha-datacenter</ManagedObjectReference>
      </val>
   </propSet>
</root>
    EOS
  end

def test_array2
  obj = VIM.DVPortStatus(
    dynamicProperty: [],
    linkUp: true,
    blocked: false,
    vmDirectPathGen2InactiveReasonNetwork: [],
    vmDirectPathGen2InactiveReasonOther: [],
    vlanIds: [
      VIM::NumericRange(dynamicProperty: [], start: 5, end: 7),
      VIM::NumericRange(dynamicProperty: [], start: 10, end: 20),
    ]
  )

  check <<-EOS, obj, 'DVPortStatus'
<root>
  <linkUp>1</linkUp>
  <blocked>false</blocked>
  <vlanIds>
    <start>5</start>
    <end>7</end>
  </vlanIds>
  <vlanIds>
    <start>10</start>
    <end>20</end>
  </vlanIds>
</root>
  EOS
end

def test_empty_array
  obj = VIM.DVPortStatus(
    dynamicProperty: [],
    vmDirectPathGen2InactiveReasonNetwork: [],
    vmDirectPathGen2InactiveReasonOther: [],
    linkUp: true,
    blocked: false,
    vlanIds: []
  )

  check <<-EOS, obj, 'DVPortStatus'
<root>
  <linkUp>1</linkUp>
  <blocked>false</blocked>
</root>
  EOS
end

  def test_fault
    obj = VIM.LocalizedMethodFault(
      localizedMessage: "The attempted operation cannot be performed in the current state (Powered off).",
      fault: VIM.InvalidPowerState(
        requestedState: 'poweredOn',
        existingState: 'poweredOff'
      )
    )

    check <<-EOS, obj, "LocalizedMethodFault"
<error xmlns:xsi="#{RbVmomi::Soap::NS_XSI}">
  <fault xsi:type="InvalidPowerState">
    <requestedState>poweredOn</requestedState>
    <existingState>poweredOff</existingState>
  </fault>
  <localizedMessage>The attempted operation cannot be performed in the current state (Powered off).</localizedMessage>
</error>
    EOS
  end

  def test_wait_for_updates
    obj = VIM.UpdateSet(
      version: '7',
      dynamicProperty: [],
      filterSet: [
        VIM.PropertyFilterUpdate(
          dynamicProperty: [],
          filter: VIM.PropertyFilter(nil, "session[528BA5EB-335B-4AF6-B49C-6160CF5E8D5B]71E3AC7E-7927-4D9E-8BC3-522769F22DAF"),
          missingSet: [],
          objectSet: [
            VIM.ObjectUpdate(
              dynamicProperty: [],
              kind: 'enter',
              obj: VIM.VirtualMachine(nil, 'vm-1106'),
              missingSet: [],
              changeSet: [
                VIM.PropertyChange(
                  dynamicProperty: [],
                  name: 'runtime.powerState',
                  op: 'assign',
                  val: 'poweredOn'
                )
              ]
            )
          ]
        )
      ]
    )

    check <<-EOS, obj, "UpdateSet"
<returnval xmlns:xsi="#{RbVmomi::Soap::NS_XSI}">
  <version>7</version>
  <filterSet>
    <filter type="PropertyFilter">session[528BA5EB-335B-4AF6-B49C-6160CF5E8D5B]71E3AC7E-7927-4D9E-8BC3-522769F22DAF</filter>
    <objectSet>
      <kind>enter</kind>
      <obj type="VirtualMachine">vm-1106</obj>
      <changeSet>
        <name>runtime.powerState</name>
        <op>assign</op>
        <val xsi:type="VirtualMachinePowerState">poweredOn</val>
      </changeSet>
    </objectSet>
  </filterSet>
</returnval>
    EOS
  end
end

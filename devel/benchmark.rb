#!/usr/bin/env ruby
require 'rbvmomi'
require 'rbvmomi/deserialization'
require 'benchmark'
require 'libxml'

NS_XSI = 'http://www.w3.org/2001/XMLSchema-instance'

VIM = RbVmomi::VIM
$conn = VIM.new(:ns => 'urn:vim25', :rev => '4.0')

def serialize obj, type, array=false
  xml = Builder::XmlMarkup.new indent: 2
  attrs = { 'xmlns:xsi' => NS_XSI }
  $conn.obj2xml(xml, 'root', type, array, obj, attrs).target!
end

def deserialize str, type
  $conn.xml2obj Nokogiri(str).root, type
end

dvport = VIM::DistributedVirtualPort(
  config: VIM::DVPortConfigInfo(
    configVersion: "0",
    dynamicProperty: [],
    scope: [],
    setting: VIM::VMwareDVSPortSetting(
      blocked: VIM::BoolPolicy( dynamicProperty: [], inherited: false, value: false
      ),
      dynamicProperty: [],
      inShapingPolicy: VIM::DVSTrafficShapingPolicy(
        averageBandwidth: VIM::LongPolicy(
          dynamicProperty: [],
          inherited: false,
          value: 100000000
        ),
        burstSize: VIM::LongPolicy(
          dynamicProperty: [],
          inherited: false,
          value: 104857600
        ),
        dynamicProperty: [],
        enabled: VIM::BoolPolicy(
          dynamicProperty: [],
          inherited: false,
          value: false
        ),
        inherited: false,
        peakBandwidth: VIM::LongPolicy(
          dynamicProperty: [],
          inherited: false,
          value: 100000000
        )
      ),
      ipfixEnabled: VIM::BoolPolicy(
        dynamicProperty: [],
        inherited: false,
        value: false
      ),
      networkResourcePoolKey: VIM::StringPolicy(
        dynamicProperty: [],
        inherited: false,
        value: "-1"
      ),
      outShapingPolicy: VIM::DVSTrafficShapingPolicy(
        averageBandwidth: VIM::LongPolicy(
          dynamicProperty: [],
          inherited: false,
          value: 100000000
        ),
        burstSize: VIM::LongPolicy(
          dynamicProperty: [],
          inherited: false,
          value: 104857600
        ),
        dynamicProperty: [],
        enabled: VIM::BoolPolicy(
          dynamicProperty: [],
          inherited: false,
          value: false
        ),
        inherited: false,
        peakBandwidth: VIM::LongPolicy(
          dynamicProperty: [],
          inherited: false,
          value: 100000000
        )
      ),
      qosTag: VIM::IntPolicy( dynamicProperty: [], inherited: false, value: -1 ),
      securityPolicy: VIM::DVSSecurityPolicy(
        allowPromiscuous: VIM::BoolPolicy(
          dynamicProperty: [],
          inherited: false,
          value: false
        ),
        dynamicProperty: [],
        forgedTransmits: VIM::BoolPolicy(
          dynamicProperty: [],
          inherited: false,
          value: true
        ),
        inherited: false,
        macChanges: VIM::BoolPolicy(
          dynamicProperty: [],
          inherited: false,
          value: true
        )
      ),
      txUplink: VIM::BoolPolicy(
        dynamicProperty: [],
        inherited: false,
        value: false
      ),
      uplinkTeamingPolicy: VIM::VmwareUplinkPortTeamingPolicy(
        dynamicProperty: [],
        failureCriteria: VIM::DVSFailureCriteria(
          checkBeacon: VIM::BoolPolicy(
            dynamicProperty: [],
            inherited: false,
            value: false
          ),
          checkDuplex: VIM::BoolPolicy(
            dynamicProperty: [],
            inherited: false,
            value: false
          ),
          checkErrorPercent: VIM::BoolPolicy(
            dynamicProperty: [],
            inherited: false,
            value: false
          ),
          checkSpeed: VIM::StringPolicy(
            dynamicProperty: [],
            inherited: false,
            value: "minimum"
          ),
          dynamicProperty: [],
          fullDuplex: VIM::BoolPolicy(
            dynamicProperty: [],
            inherited: false,
            value: false
          ),
          inherited: false,
          percentage: VIM::IntPolicy(
            dynamicProperty: [],
            inherited: false,
            value: 0
          ),
          speed: VIM::IntPolicy( dynamicProperty: [], inherited: false, value: 10 )
        ),
        inherited: false,
        notifySwitches: VIM::BoolPolicy(
          dynamicProperty: [],
          inherited: false,
          value: true
        ),
        policy: VIM::StringPolicy(
          dynamicProperty: [],
          inherited: false,
          value: "loadbalance_srcid"
        ),
        reversePolicy: VIM::BoolPolicy(
          dynamicProperty: [],
          inherited: false,
          value: true
        ),
        rollingOrder: VIM::BoolPolicy(
          dynamicProperty: [],
          inherited: false,
          value: false
        ),
        uplinkPortOrder: VIM::VMwareUplinkPortOrderPolicy(
          activeUplinkPort: ["dvUplink1", "dvUplink2"],
          dynamicProperty: [],
          inherited: false,
          standbyUplinkPort: []
        )
      ),
      vendorSpecificConfig: VIM::DVSVendorSpecificConfig(
        dynamicProperty: [],
        inherited: false,
        keyValue: []
      ),
      vlan: VIM::VmwareDistributedVirtualSwitchVlanIdSpec(
        dynamicProperty: [],
        inherited: false,
        vlanId: 962
      ),
      vmDirectPathGen2Allowed: VIM::BoolPolicy(
        dynamicProperty: [],
        inherited: false,
        value: false
      )
    )
  ),
  conflict: true,
  conflictPortKey: "5488",
  connectee: VIM::DistributedVirtualSwitchPortConnectee(
    connectedEntity: VIM::VirtualMachine($conn, "vm-75104"),
    dynamicProperty: [],
    nicKey: "4001",
    type: "vmVnic"
  ),
  connectionCookie: 98679995,
  dvsUuid: "00 f8 31 50 a0 c3 38 f5-57 0b 78 0b ff 0f 3f 25",
  dynamicProperty: [],
  key: "c-10437",
  #lastStatusChange: DateTime.new,
  proxyHost: VIM::HostSystem($conn, "host-77")
)

do_serialize = lambda { serialize dvport, 'DistributedVirtualPort' }
serialized_dvport = do_serialize[]
parsed_dvport_nokogiri = Nokogiri(serialized_dvport)
parsed_dvport_libxml = LibXML::XML::Parser.string(serialized_dvport).parse
do_deserialize = lambda { deserialize serialized_dvport, 'DistributedVirtualPort' }
deserialized_dvport = do_deserialize[]

def traverse node
  node.children.each do |child|
    traverse child
  end
end

N = 1000

Benchmark.bmbm do|b|
=begin
  b.report("serialization") do
    N.times { do_serialize[] }
  end
=end

  GC.start
  
  b.report("nokogiri parsing") do
    N.times { Nokogiri(serialized_dvport) }
  end
  
  GC.start
  
  b.report("recursive traversal of nokogiri") do
    N.times { traverse parsed_dvport_nokogiri.root }
  end
  
  GC.start

  b.report("libxml parsing") do
    N.times do
      LibXML::XML::Parser.string(serialized_dvport).parse
    end
  end
  
  GC.start
  
  b.report("recursive traversal of libxml") do
    N.times { traverse parsed_dvport_libxml.root }
  end
  
  GC.start

  b.report("deserialization") do
    N.times { do_deserialize[] }
  end

  GC.start

  b.report("new deserialization") do
    deserializer = RbVmomi::Deserializer.new($conn)
    N.times do
      deserializer.deserialize Nokogiri::XML(serialized_dvport).root
    end
  end
end

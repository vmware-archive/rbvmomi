# frozen_string_literal: true
# Copyright (c) 2011-2017 VMware, Inc.  All Rights Reserved.
# SPDX-License-Identifier: MIT

require "test_helper"

class MiscTest < Test::Unit::TestCase
  def test_overridden_const
    assert(VIM::SecurityError < RbVmomi::BasicTypes::Base)
    assert_equal "SecurityError", VIM::SecurityError.wsdl_name
  end

  # XXX
  def disabled_test_dynamically_overridden_const
    assert !VIM.const_defined?(:ClusterAttemptedVmInfo)
    Object.const_set :ClusterAttemptedVmInfo, :override
    assert VIM::ClusterAttemptedVmInfo.is_a?(Class)
    assert(VIM::ClusterAttemptedVmInfo < RbVmomi::BasicTypes::Base)
    assert_equal "ClusterAttemptedVmInfo", VIM::ClusterAttemptedVmInfo.wsdl_name
  end

  def test_loader
    klass = VIM.loader.get("HostSystem")
    klass2 = VIM::HostSystem
    assert_equal klass, klass2
  end

  def test_managed_object_to_hash
    assert_equal VIM.VirtualMachine(nil, "vm-123").to_hash, "VirtualMachine(\"vm-123\")"
  end

  def test_managed_object_to_json
    assert_equal VIM.VirtualMachine(nil, "vm-123").to_json, "\"VirtualMachine(\\\"vm-123\\\")\""
  end

  def test_data_object_to_hash
    # With a nested ManagedObject value
    assert_equal VIM.VirtualMachineSummary({ vm: VIM.VirtualMachine(nil, "vm-123") }).to_hash, { vm: "VirtualMachine(\"vm-123\")" }

    # With an array
    assert_equal VIM.VirtualMachineSummary({ customValue: [VIM.CustomFieldValue({ key: 1 })] }).to_hash, { customValue: [{ key: 1 }] }

    # With an Enum
    assert_equal VIM.VirtualMachineSummary({ overallStatus: VIM.ManagedEntityStatus("green") }).to_hash, { overallStatus: "green" }

    # Combined
    assert_equal VIM.VirtualMachineSummary(
      vm: VIM.VirtualMachine(nil, "vm-123"),
      customValue: [VIM.CustomFieldValue(key: 1)],
      overallStatus: VIM.ManagedEntityStatus("green")
    ).to_hash,
                 {
                   vm: "VirtualMachine(\"vm-123\")",
                   customValue: [{ key: 1 }],
                   overallStatus: "green"
                 }
  end

  def test_data_object_to_json
    # With a nested ManagedObject value
    assert_equal VIM.VirtualMachineSummary({ vm: VIM.VirtualMachine(nil, "vm-123") }).to_json,
                 "{\"vm\":\"VirtualMachine(\\\"vm-123\\\")\",\"json_class\":\"RbVmomi::VIM::VirtualMachineSummary\"}"

    # With an array
    assert_equal VIM.VirtualMachineSummary({ customValue: [VIM.CustomFieldValue({ key: 1 })] }).to_json,
                 "{\"customValue\":[{\"key\":1}],\"json_class\":\"RbVmomi::VIM::VirtualMachineSummary\"}"

    # With an Enum
    assert_equal VIM.VirtualMachineSummary({ overallStatus: VIM.ManagedEntityStatus("green") }).to_json,
                 "{\"overallStatus\":\"green\",\"json_class\":\"RbVmomi::VIM::VirtualMachineSummary\"}"

    # Combined
    assert_equal VIM.VirtualMachineSummary(
      vm: VIM.VirtualMachine(nil, "vm-123"),
      customValue: [VIM.CustomFieldValue(key: 1)],
      overallStatus: VIM.ManagedEntityStatus("green")
    ).to_json,
                 "{\"vm\":\"VirtualMachine(\\\"vm-123\\\")\",\"customValue\":[{\"key\":1}],\"overallStatus\":\"green\",\"json_class\":\"RbVmomi::VIM::VirtualMachineSummary\"}"
  end
end

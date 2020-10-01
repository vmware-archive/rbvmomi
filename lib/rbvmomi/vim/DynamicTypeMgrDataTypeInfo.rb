# frozen_string_literal: true
# Copyright (c) 2011-2017 VMware, Inc.  All Rights Reserved.
# SPDX-License-Identifier: MIT

module RbVmomi
  module VIM
    class DynamicTypeMgrDataTypeInfo
      def toRbvmomiTypeHash
        {
          wsdlName => {
            "kind" => "data",
            "type-id" => name,
            "base-type-id" => base.first,
            "props" => property.map do |prop|
              {
                "name" => prop.name,
                "type-id-ref" => prop.type.gsub("[]", ""),
                "is-array" => (prop.type =~ /\[\]$/) ? true : false,
                "is-optional" => prop.annotation.find { |a| a.name == "optional"} ? true : false,
                "version-id-ref" => prop.version
              }
            end
          }
        }
      end
    end
  end
end

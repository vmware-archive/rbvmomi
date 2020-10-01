# frozen_string_literal: true
# Copyright (c) 2011-2017 VMware, Inc.  All Rights Reserved.
# SPDX-License-Identifier: MIT

module RbVmomi
  module VIM
    class DynamicTypeMgrManagedTypeInfo
      def toRbvmomiTypeHash
        {
          wsdlName => {
            "kind" => "managed",
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
            end,
            "methods" => Hash[
              method.map do |method|
                result = method.returnTypeInfo

                [method.wsdlName,
                 {
                   "params" => method.paramTypeInfo.map do |param|
                     {
                       "name" => param.name,
                       "type-id-ref" => param.type.gsub("[]", ""),
                       "is-array" => (param.type =~ /\[\]$/) ? true : false,
                       "is-optional" => param.annotation.find { |a| a.name == "optional"} ? true : false,
                       "version-id-ref" => param.version
                     }
                   end,
                   "result" => (
                   if result.nil?
                     nil
                   else
                     {
                       "name" => result.name,
                       "type-id-ref" => result.type.gsub("[]", ""),
                       "is-array" => (result.type =~ /\[\]$/) ? true : false,
                       "is-optional" => result.annotation.find { |a| a.name == "optional"} ? true : false,
                       "version-id-ref" => result.version
                     }
                   end)
                 }]
              end
            ]
          }
        }
      end
    end
  end
end

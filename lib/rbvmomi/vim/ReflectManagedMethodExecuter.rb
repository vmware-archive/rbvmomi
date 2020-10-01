# frozen_string_literal: true
# Copyright (c) 2011-2017 VMware, Inc.  All Rights Reserved.
# SPDX-License-Identifier: MIT

module RbVmomi
  module VIM
    class ReflectManagedMethodExecuter
      def fetch moid, prop
        result = FetchSoap(moid: moid, version: "urn:vim25/6.5", prop: prop)
        xml = Nokogiri(result.response)
        _connection.deserializer.deserialize xml.root, nil
      end

      def execute moid, method, args
        soap_args = args.map do |k, v|
          VIM::ReflectManagedMethodExecuterSoapArgument.new.tap do |soap_arg|
            soap_arg.name = k
            xml = Builder::XmlMarkup.new indent: 0
            _connection.obj2xml xml, k, :anyType, false, v
            soap_arg.val = xml.target!
          end
        end
        result = ExecuteSoap(moid: moid, version: "urn:vim25/6.5",
                             method: method, argument: soap_args)
        _connection.deserializer.deserialize Nokogiri(result.response).root, nil if result
      end
    end
  end
end

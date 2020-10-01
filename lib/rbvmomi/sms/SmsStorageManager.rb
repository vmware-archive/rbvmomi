# frozen_string_literal: true
# Copyright (c) 2013-2017 VMware, Inc.  All Rights Reserved.
# SPDX-License-Identifier: MIT

module RbVmomi
  module SMS
    class SmsStorageManager
      def RegisterProvider_Task2 providerSpec
        self.RegisterProvider_Task providerSpec
      end
    end
  end
end

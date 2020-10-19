# frozen_string_literal: true
# Copyright (c) 2010-2019 VMware, Inc.  All Rights Reserved.
# SPDX-License-Identifier: MIT

# RbVmomi is a Ruby interface to the vSphere management interface
module RbVmomi
  # @private
  # @deprecated Use +RbVmomi::VIM.connect+.
  def self.connect(opts)
    VIM.connect opts
  end
end

require_relative 'rbvmomi/connection'
require_relative 'rbvmomi/sso'
require_relative 'rbvmomi/version'
require_relative 'rbvmomi/vim'

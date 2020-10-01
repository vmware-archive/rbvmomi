# frozen_string_literal: true
# Copyright (c) 2011-2017 VMware, Inc.  All Rights Reserved.
# SPDX-License-Identifier: MIT

require "simplecov"
SimpleCov.start { add_filter "/test/" }

require "rbvmomi"
VIM = RbVmomi::VIM

require "test/unit"

# frozen_string_literal: true
# Copyright (c) 2011-2017 VMware, Inc.  All Rights Reserved.
# SPDX-License-Identifier: MIT

# Translation of example 2-2 from the vSphere SDK for Perl Programming Guide
require "optimist"
require "rbvmomi"
require "rbvmomi/optimist"

VIM = RbVmomi::VIM

opts = Optimist.options do
  banner <<~EOS
    Follow a log file.
    
    Usage:
        logtail.rb [options] [logKey]
    
    If logKey is not provided the list of available log keys will be printed and
    the program will exit.
    
    VIM connection options:
  EOS

  rbvmomi_connection_opts

  text <<~EOS
    
    Other options:
  EOS
end

Optimist.die("must specify host") unless opts[:host]
logKey = ARGV[0]

vim = VIM.connect opts
diagMgr = vim.service_content.diagnosticManager

unless logKey
  puts "Available logs:"
  diagMgr.QueryDescriptions.each do |desc|
    puts "#{desc.key}: #{desc.info.label}"
  end
  exit 0
end

# Obtain the last line of the logfile by setting an arbitrarily large
# line number as the starting point
log = diagMgr.BrowseDiagnosticLog(key: logKey, start: 999_999_999)
lineEnd = log.lineEnd

# Get the last 5 lines of the log first, and then check every 2 seconds
# to see if the log size has increased.
start = lineEnd - 5
loop do
  log = diagMgr.BrowseDiagnosticLog(key: logKey, start: start)
  if log.lineStart != 0
    log.lineText.each do |l|
      puts l
    end
  end
  start = log.lineEnd + 1
  sleep 2
end

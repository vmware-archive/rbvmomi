# RbVmomi

[<img src="https://badge.fury.io/rb/rbvmomi.svg" alt="gem-version">](https://rubygems.org/gems/rbvmomi) 
[<img src="https://travis-ci.org/vmware/rbvmomi.svg?branch=master" alt="travis-ci">](http://travis-ci.org/vmware/rbvmomi) 
[<img src="https://badges.gitter.im/vmware/rbvmomi.svg">](https://gitter.im/vmware/rbvmomi)

This is a community-supported, open source project at VMware. It is built and
maintained by programmers like you!

## Introduction

RbVmomi is a Ruby interface to the vSphere API. Like the Perl and Java SDKs,
you can use it to manage ESX and vCenter servers. The current release
supports the vSphere 6.5 API. RbVmomi specific documentation is
[online](http://rdoc.info/github/vmware/rbvmomi/master/frames) and is meant to
be used alongside the official [documentation](http://pubs.vmware.com/vsphere-65/index.jsp#com.vmware.wssdk.apiref.doc/right-pane.html).

## Installation

    gem install rbvmomi

### Support for older Ruby versions

RbVmomi supports Ruby 1.8.7 and higher, but certain dependencies may need
pinning to older versions to get a compatible set of gems.

On Ruby 1.8.7:

* use `nokogiri` 1.5.x (Gemfile: `gem 'nokogiri', '< 1.6'`)


On both Ruby 1.9 and 1.8.7:

* use `json` 1.x (Gemfile: `gem 'json', '< 2'`)


## Usage

A simple example of turning on a VM:

```ruby
require 'rbvmomi'

vim = RbVmomi::VIM.connect(host: 'foo', user: 'bar', password: 'baz')
dc = vim.serviceInstance.find_datacenter('my_datacenter') || fail('datacenter not found')
vm = dc.find_vm('my_vm') || fail('VM not found')
vm.PowerOnVM_Task.wait_for_completion
```

This code uses several RbVmomi extensions to the vSphere API for concision.
The expanded snippet below uses only standard API calls and should be familiar
to users of the Java SDK:

```ruby
require 'rbvmomi'

vim = RbVmomi::VIM.connect(host: 'foo', user: 'bar', password: 'baz')
root_folder = vim.serviceInstance.content.rootFolder
dc = root_folder.childEntity.grep(RbVmomi::VIM::Datacenter).find { |x| x.name == 'mydatacenter' } || fail('datacenter not found')
vm = dc.vmFolder.childEntity.grep(RbVmomi::VIM::VirtualMachine).find { |x| x.name == 'my_vm' } || fail('VM not found')
task = vm.PowerOnVM_Task
filter = vim.propertyCollector.CreateFilter(
  spec: {
    propSet: [{ type: 'Task', all: false, pathSet: ['info.state']}],
    objectSet: [{ obj: task }]
  },
  partialUpdates: false
)
ver = ''
loop do
  result = vim.propertyCollector.WaitForUpdates(version: ver)
  ver = result.version
  break if ['success', 'error'].member?(task.info.state)
end
filter.DestroyPropertyFilter
raise(task.info.error) if task.info.state == 'error'
```

As you can see, the extensions RbVmomi adds can dramatically decrease the code
needed to perform simple tasks while still letting you use the full power of
the API when necessary. RbVmomi extensions are often more efficient than a
naive implementation; for example, the find_vm method on VIM::Datacenter used
in the first example uses the SearchIndex for fast lookups.

A few important points:

*   All class, method, parameter, and property names match the official [documentation](http://pubs.vmware.com/vsphere-65/index.jsp#com.vmware.wssdk.apiref.doc/right-pane.html).
*   Properties are exposed as accessor methods.
*   Data object types can usually be inferred from context, so you may use a hash instead.
*   Enumeration values are simply strings.
*   Example code is included in the examples/ directory.
*   A set of helper methods for Optimist is included to speed up development of
    command line apps. See the included examples for usage.
*   If you don't have trusted SSL certificates installed on the host you're
    connecting to, you'll get an `OpenSSL::SSL::SSLError` "certificate verify
    failed". You can work around this by using the `:insecure` option to
    `RbVmomi::VIM.connect`.
*   This is a side project of a VMware employee and is entirely unsupported by
    VMware.


Built-in extensions are under `lib/rbvmomi/vim/`. You are encouraged to reopen
VIM classes in your applications and add extensions of your own. If you write
something generally useful please open a [pull request](https://github.com/vmware/rbvmomi/pulls) so it can be merged back in

## Development

Open an issue on the [issues page](https://github.com/vmware/rbvmomi/issues)
or  fork the project on [GitHub](https://github.com/vmware/rbvmomi) and send a
[pull request](https://github.com/vmware/rbvmomi/pulls).

## Support

You can chat on [Gitter](https://gitter.im/vmware/rbvmomi) or join the [VMware {code} Slack team](https://vmwarecode.slack.com/) and join the [#rbvmomi channel](https://vmwarecode.slack.com/messages/rbvmomi).

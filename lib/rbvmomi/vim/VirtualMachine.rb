class RbVmomi::VIM::VirtualMachine
  # Retrieve the MAC addresses for all virtual NICs.
  # @return [Hash] Keyed by device label.
  def macs
    Hash[self.config.hardware.device.grep(RbVmomi::VIM::VirtualEthernetCard).map { |x| [x.deviceInfo.label, x.macAddress] }]
  end
  
  # Retrieve all virtual disk devices.
  # @return [Array] Array of virtual disk devices.
  def disks
    self.config.hardware.device.grep(RbVmomi::VIM::VirtualDisk)
  end
  
  # Get the IP of the guest, but only if it is not stale 
  # @return [String] Current IP reported (as per VMware Tools) or nil
  def guest_ip 
    g = self.guest
    if g.ipAddress && (g.toolsStatus == "toolsOk" || g.toolsStatus == "toolsOld")
      g.ipAddress
    else
      nil
    end
  end  

  # Add a layer of delta disks (redo logs) in front of every disk on the VM.
  # This is similar to taking a snapshot and makes the VM a valid target for
  # creating a linked clone.
  #
  # Background: The API for linked clones is quite strange. We can't create 
  # a linked straight from any VM. The disks of the VM for which we can create a
  # linked clone need to be read-only and thus VC demands that the VM we
  # are cloning from uses delta-disks. Only then it will allow us to
  # share the base disk.
  def add_delta_disk_layer_on_all_disks
    devices,  = self.collect 'config.hardware.device'
    disks = devices.grep(RbVmomi::VIM::VirtualDisk)
    spec = update_spec_add_delta_disk_layer_on_all_disks
    self.ReconfigVM_Task(:spec => spec).wait_for_completion
  end
  
  # Updates a passed in spec to perform the task of adding a delta disk layer
  # on top of all disks. Does the same as add_delta_disk_layer_on_all_disks
  # but instead of issuing the ReconfigVM_Task, it just constructs the 
  # spec, so that the caller can batch a couple of updates into one 
  # ReconfigVM_Task.
  def update_spec_add_delta_disk_layer_on_all_disks spec = {}
    devices,  = self.collect 'config.hardware.device'
    disks = devices.grep(RbVmomi::VIM::VirtualDisk)
    device_change = []
    disks.each do |disk|
      device_change << {
        :operation => :remove,
        :device => disk
      }
      device_change << {
        :operation => :add,
        :fileOperation => :create,
        :device => disk.dup.tap { |x|
          x.backing = x.backing.dup
          x.backing.fileName = "[#{disk.backing.datastore.name}]"
          x.backing.parent = disk.backing
        },
      }
    end
    if spec.is_a?(RbVmomi::VIM::VirtualMachineConfigSpec)
      spec.deviceChange ||= []
      spec.deviceChange += device_change
    else
      spec[:deviceChange] ||= []
      spec[:deviceChange] += device_change
    end
    spec
  end

  # Retrieve all virtual controllers
  # @return [Array] Array of virtual controllers
  def controllers
    self.config.hardware.device.grep(RbVmomi::VIM::VirtualController)
  end

  # Add specified file as a disk to VM
  # @param datastore [RbVmomi::VIM::Datastore] the datastore hosting the VMDK to be added
  # @param file [String] the name of the file we want to add
  # @param file_path (optional) [String] the path to the file
  # @param controller (optional) [String] the controller to add the VirtualDisk to. 
  #   Defaults to "SCSI controller 0"
  # @return nil on success
  def add_disk(options={})
    defaults = {
      :controller => "SCSI controller 0",
    }
    options = defaults.merge(options)
    fail "Please provide a datastore" unless options[:datastore].is_a? RbVmomi::VIM::Datastore

    @ds = options[:datastore]
    @file = options[:file]
    @file_path = options[:vmdk_path]
    @controller = options[:controller]

    if @vmdk_path.nil?
      @file_path = @ds.find_file_path(@file)
    else 
      @file_path = @vmdk_path
    end

    @full_file_path = "[#{@ds.info.name}] #{@file_path}#{@file}"

    @disk_backing_info = RbVmomi::VIM::VirtualDiskFlatVer2BackingInfo.new(  :datastore => @ds, 
                                                                            :fileName => @full_file_path, 
                                                                            :diskMode => "persistent")

    @vm_controllers = self.controllers

    @vm_controller = nil
    @vm_controllers.each { |c| @vm_controller = c if c.deviceInfo.label == @controller }
    fail "Could not find Virtual Controller #{@controller}" if @vm_controller.nil?

    # Because the unit number starts at 0, count will return the next value we can use
    @unit_number = @vm_controller.device.count

    @capacityKb  = @ds.get_file_info(:file => @file, :path => @file_path).capacityKb
    @disk = RbVmomi::VIM::VirtualDisk.new(:controllerKey => @vm_controller.key, 
                                          :unitNumber => @unit_number,
                                          :key => -1,
                                          :backing => @disk_backing_info,
                                          :capacityInKB => @capacityKb)
    @dev_spec = RbVmomi::VIM::VirtualDeviceConfigSpec.new(  :operation => RbVmomi::VIM::VirtualDeviceConfigSpecOperation.new('add'),
                                                            :device => @disk)
    @vm_spec = RbVmomi::VIM::VirtualMachineConfigSpec.new( :deviceChange => [*@dev_spec] )

    puts "Reconfiguring #{self.name} to add VMDK: #{@full_file_path}"
    ReconfigVM_Task( :spec => @vm_spec ).wait_for_completion
  end

  # Remove specified disk from the VM
  # @param datastore [RbVmomi::VIM::Datastore] the datastore hosting the file to be removed
  # @param file [String] the name of the disk file we want to remove
  # @param file_path (optional) [String] the path to the disk file
  # @param destroy (optional) [Boolean] whether or not to delete the underlying disk file
  # @return nil on success
  def remove_disk(options={})
    defaults = {
      :destroy => false,
    }
    options = defaults.merge(options)
    @ds = options[:datastore]
    @file = options[:file]
    @file_path = options[:file_path]
    @destroy = options[:destroy]

    if @file_path.nil?
      @file_path = @ds.find_file_path(@file)
    end

    fail "Please provide a datastore" unless @ds.is_a? RbVmomi::VIM::Datastore

    @disk = self.find_disk(:datastore => @ds, :file => "#{@file_path}#{@file}")

    fail "Couldn't find disk attached to #{self.name} for file #{@file}" if @disk.nil?

    @config_remove_operation = RbVmomi::VIM::VirtualDeviceConfigSpecOperation.new('remove');
    if @destroy
      @config_destroy_operation = RbVmomi::VIM::VirtualDeviceConfigSpecFileOperation.new('destroy');
      @device_spec = RbVmomi::VIM::VirtualDeviceConfigSpec.new( :operation => @config_remove_operation,
                                                                :device => @disk,
                                                                :fileOperations => @config_destroy_operation)

      puts "Reconfiguring #{self.name} to destroy disk #{@file_path}#{@file}"
    else
      @device_spec = RbVmomi::VIM::VirtualDeviceConfigSpec.new( :operation => @config_remove_operation,
                                                                :device => @disk)
      puts "Reconfiguring #{self.name} to remove disk #{@file_path}#{@file}"
    end

    @vm_spec = RbVmomi::VIM::VirtualMachineConfigSpec.new(:deviceChange => [*@device_spec])

    ReconfigVM_Task(:spec => @vm_spec).wait_for_completion
  end

  # Find a disk attached to this VM
  # @param file [String] the name of the file for the VirtualDisk
  # @param datastore [RbVmomi::VIM::Datastore] the datastore to look for the disk in
  # @return pRbVmomi::VIM::VirtualDevice] for the disk
  def find_disk(options={})
    @file = options[:file]
    @datastore = options[:datastore]

    @disk = nil
    @devices = self.disks
    @devices.each do |device|
      next unless device.backing.is_a? RbVmomi::VIM::VirtualDeviceFileBackingInfo
      @device_datastore,@device_file = device.backing.fileName.gsub(/(\[|\])/, '').split(' ')
      if @device_file == @file and @device_datastore == @datastore.info.name
        return device
      end
    end

    fail "Didn't find disk for file #{@file}"
  end
end

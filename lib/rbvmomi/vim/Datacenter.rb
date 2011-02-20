class RbVmomi::VIM::Datacenter
  def find_compute_resource path=nil
    if path
      hostFolder.traverse path, RbVmomi::VIM::ComputeResource
    else
      hostFolder.childEntity.grep(RbVmomi::VIM::ComputeResource).first
    end
  end

  def find_datastore name
    datastore.find { |x| x.name == name }
  end

  def find_vm path
    vmFolder.traverse path, RbVmomi::VIM::VirtualMachine
  end
end


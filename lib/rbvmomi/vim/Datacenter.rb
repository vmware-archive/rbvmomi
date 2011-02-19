class RbVmomi::VIM::Datacenter
  def find_compute_resource path=nil
    if path
      hostFolder.traverse path, VIM::ComputeResource
    else
      hostFolder.childEntity.grep(VIM::ComputeResource).first
    end
  end

  def find_datastore name
    datastore.find { |x| x.name == name }
  end

  def find_vm folder_path, name
    vmFolder.traverse "#{folder_path}/#{name}", VIM::VirtualMachine
  end
end


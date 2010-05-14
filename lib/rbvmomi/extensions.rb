module RbVmomi::VIM

class ManagedObject
  def wait *pathSet
    all = pathSet.empty?
    filter = @soap.propertyCollector.CreateFilter :spec => {
      :propSet => [{ :type => self.class.wsdl_name, :all => all, :pathSet => pathSet }],
      :objectSet => [{ :obj => self }],
    }, :partialUpdates => false
    result = @soap.propertyCollector.WaitForUpdates
    filter.DestroyPropertyFilter
    changes = result.filterSet[0].objectSet[0].changeSet
    changes.map { |h| [h.name.split('.').map(&:to_sym), h.val] }.each do |path,v|
      k = path.pop
      o = path.inject(self) { |b,k| b[k] }
      o._set_property k, v unless o == self
    end
    nil
  end

  def wait_until *pathSet, &b
    loop do
      wait *pathSet
      if x = b.call
        return x
      end
    end
  end
end

Task
class Task
  def wait_for_completion
    wait_until('info.state') { %w(success error).member? info.state }
    case info.state
    when 'success'
      info.result
    when 'error'
      fail "task #{info.key} failed: #{info.error.localizedMessage}"
    end
  end
end

Folder
class Folder
  def find name, type=Object
    childEntity.grep(type).find { |x| x.name == name }
  end

  def traverse path, type=Object
    es = path.split('/')
    return self if es.empty?
    final = es.pop
    es.inject(self) do |f,e|
      f.find e, Folder or return nil
    end.find final, type
  end

  def children
    childEntity
  end

  def ls
    Hash[children.map { |x| [x.name, x] }]
  end
end



end

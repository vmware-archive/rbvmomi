module RbVmomi::VIM

class ManagedObject
  def wait
    filter = @soap.propertyCollector.CreateFilter :spec => {
      :propSet => [{ :type => self.class.wsdl_name, :all => true }],
      :objectSet => [{ :obj => self }],
    }, :partialUpdates => false
    result = @soap.propertyCollector.WaitForUpdates
    filter.DestroyPropertyFilter
    changes = result.filterSet[0].objectSet[0].changeSet
    changes.map { |h| [h.name.to_sym, h.val] }.each do |k,v|
      @cache[k] = v
    end
  end

  def wait_until &b
    loop do
      wait
      if x = b.call
        return x
      end
    end
  end
end

Task
class Task
  def wait_for_completion
    wait_until { %w(success error).member? info.state }
    case info.state
    when 'success'
      info.result
    when 'error'
      fail "task #{info.key} failed: #{info.error.localizedMessage}"
    end
  end
end

end

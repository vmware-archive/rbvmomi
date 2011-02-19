class RbVmomi::VIM::Task
  def wait_for_completion
    wait_until('info.state') { %w(success error).member? info.state }
    case info.state
    when 'success'
      info.result
    when 'error'
      raise info.error
    end
  end

  def wait_for_progress
    wait_until('info.state', 'info.progress') do
      yield info.progress if block_given?
      %w(success error).member? info.state
    end
    case info.state
    when 'success'
      info.result
    when 'error'
      raise info.error
    end
  end
end

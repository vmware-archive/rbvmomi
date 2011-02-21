class RbVmomi::VIM::Task
  # Wait for a task to finish.
  # @return +info.result+ on success.
  # @raise +info.error+ on error.
  def wait_for_completion
    wait_until('info.state') { %w(success error).member? info.state }
    case info.state
    when 'success'
      info.result
    when 'error'
      raise info.error
    end
  end

  # Wait for a task to finish, with progress notifications.
  # @return (see #wait_for_completion)
  # @raise (see #wait_for_completion)
  # @yield [info.progress]
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

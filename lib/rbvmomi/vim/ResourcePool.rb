class RbVmomi::VIM::ResourcePool
  # Retrieve a child ResourcePool.
  # @param name [String] Name of the child.
  # @return [VIM::ResourcePool]
  def find name
    @soap.searchIndex.FindChild(:entity => self, :name => name)
  end

  # Retrieve a descendant of this ResourcePool.
  # @param path [String] Path delimited by '/'.
  # @return [VIM::ResourcePool]
  def traverse path
    es = path.split('/').reject(&:empty?)
    es.inject(self) do |f,e|
      f.find(e) || return
    end
  end
end

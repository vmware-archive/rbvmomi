class RbVmomi::VIM::ResourcePool
  def traverse path
    es = path.split('/').reject(&:empty?)
    return self if es.empty?
    es.inject(self) do |f,e|
      @soap.searchIndex.FindChild(entity: f, name: e) || return
    end
  end
end

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

  def resourcePoolSubTree fields = []
    self.class.resourcePoolSubTree self, fields
  end
  
  def self.resourcePoolSubTree objs, fields = []
    fields = (fields + ['name', 'resourcePool']).uniq
    i = 0
    filterSpec = RbVmomi::VIM.PropertyFilterSpec(
      :objectSet => objs.map do |obj|
        i += 1
        RbVmomi::VIM.ObjectSpec(
          :obj => obj,
          :selectSet => [
            RbVmomi::VIM.TraversalSpec(
              :name => "tsME-#{i}",
              :type => 'ResourcePool',
              :path => 'resourcePool',
              :skip => false,
              :selectSet => [
                RbVmomi::VIM.SelectionSpec(:name => "tsME-#{i}")
              ]
            )
          ]
        )
      end,
      :propSet => [{
        :pathSet => fields,
        :type => 'ResourcePool'
      }]
    )
  
    propCollector = objs.first._connection.propertyCollector
    result = propCollector.RetrieveProperties(:specSet => [filterSpec])
    
    hash = Hash[result.map do |x| 
      [
        x.obj, 
        Hash[ fields.map{|f| [f.to_sym, x.propSet.find{|y| y.name == f}.val] } ]
      ]
    end]
  end
end

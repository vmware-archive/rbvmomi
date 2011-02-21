class RbVmomi::VIM::ManagedEntity
  # Retrieve the ancestors of the entity.
  # @return [Array] Ancestors of this entity, starting with the root.
  def path
    filterSpec = RbVmomi::VIM.PropertyFilterSpec(
      :objectSet => [{
        :obj => self,
        :selectSet => [
          RbVmomi::VIM.TraversalSpec(
            :name => 'tsME',
            :type => 'ManagedEntity',
            :path => 'parent',
            :skip => false,
            :selectSet => [
              RbVmomi::VIM.SelectionSpec(:name => 'tsME')
            ]
          )
        ]
      }],
      :propSet => [{
        :pathSet => %w(name parent),
        :type => 'ManagedEntity'
      }]
    )

    result = @soap.propertyCollector.RetrieveProperties(:specSet => [filterSpec])

    tree = {}
    result.each { |x| tree[x.obj] = [x['parent'], x['name']] }
    a = []
    cur = self
    while cur
      parent, name = *tree[cur]
      a << [cur, name]
      cur = parent
    end
    a.reverse
  end

  # Return a string representation of +path+ suitable for display.
  # @return [String]
  # @see #path
  def pretty_path
    path[1..-1].map { |x| x[1] } * '/'
  end
end

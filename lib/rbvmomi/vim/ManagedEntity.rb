class RbVmomi::VIM::ManagedEntity
  def path
    filterSpec = VIM.PropertyFilterSpec(
      objectSet: [{
        obj: self,
        selectSet: [
          VIM.TraversalSpec(
            name: 'tsME',
            type: 'ManagedEntity',
            path: 'parent',
            skip: false,
            selectSet: [
              VIM.SelectionSpec(name: 'tsME')
            ]
          )
        ]
      }],
      propSet: [{
        pathSet: %w(name parent),
        type: 'ManagedEntity'
      }]
    )

    result = @soap.propertyCollector.RetrieveProperties(specSet: [filterSpec])

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

  def pretty_path
    path[1..-1].map { |x| x[1] } * '/'
  end
end

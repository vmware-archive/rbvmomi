class RbVmomi::VIM::Folder
  def find name, type=Object
    x = @soap.searchIndex.FindChild(entity: self, name: name)
    x if x.is_a? type
  end

  def traverse! path, type=Object
    traverse path, type, true
  end

  def traverse path, type=Object, create=false
    es = path.split('/').reject(&:empty?)
    return self if es.empty?
    final = es.pop

    p = es.inject(self) do |f,e|
      f.find(e, Folder) || (create && f.CreateFolder(name: e)) || return
    end

    if x = p.find(final, type)
      x
    elsif create and type == Folder
      p.CreateFolder(name: final)
    else
      nil
    end
  end

  def children
    childEntity
  end

  def ls
    Hash[children.map { |x| [x.name, x] }]
  end

  def inventory propSpecs={}
    propSet = [{ type: 'Folder', pathSet: ['name', 'parent'] }]
    propSpecs.each do |k,v|
      case k
      when VIM::ManagedEntity
        k = k.wsdl_name
      when Symbol, String
        k = k.to_s
      else
        fail "key must be a ManagedEntity"
      end

      h = { type: k }
      if v == :all
        h[:all] = true
      elsif v.is_a? Array
        h[:pathSet] = v + %w(parent)
      else
        fail "value must be an array of property paths or :all"
      end
      propSet << h
    end

    filterSpec = VIM.PropertyFilterSpec(
      objectSet: [
        obj: self,
        selectSet: [
          VIM.TraversalSpec(
            name: 'tsFolder',
            type: 'Folder',
            path: 'childEntity',
            skip: false,
            selectSet: [
              VIM.SelectionSpec(name: 'tsFolder')
            ]
          )
        ]
      ],
      propSet: propSet
    )

    result = @soap.propertyCollector.RetrieveProperties(specSet: [filterSpec])

    tree = { self => {} }
    result.each do |x|
      obj = x.obj
      next if obj == self
      h = Hash[x.propSet.map { |y| [y.name, y.val] }]
      tree[h['parent']][h['name']] = [obj, h]
      tree[obj] = {} if obj.is_a? VIM::Folder
    end
    tree
  end
end

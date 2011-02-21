class RbVmomi::VIM::Folder
  # Retrieve a child entity
  # @param name [String] Name of the child.
  # @param type [Class] Return nil unless the found entity <tt>is_a? type</tt>.
  # @return [VIM::ManagedEntity]
  def find name, type=Object
    x = @soap.searchIndex.FindChild(:entity => self, :name => name)
    x if x.is_a? type
  end

  # Alias to <tt>traverse path, type, true</tt>
  # @see #traverse
  def traverse! path, type=Object
    traverse path, type, true
  end

  # Retrieve a descendant of this Folder.
  # @param path [String] Path delimited by '/'.
  # @param type (see Folder#find)
  # @param create [Boolean] If set, create folders that don't exist.
  # @return (see Folder#find)
  # @todo Move +create+ functionality into another method.
  def traverse path, type=Object, create=false
    es = path.split('/').reject(&:empty?)
    return self if es.empty?
    final = es.pop

    p = es.inject(self) do |f,e|
      f.find(e, Folder) || (create && f.CreateFolder(:name => e)) || return
    end

    if x = p.find(final, type)
      x
    elsif create and type == Folder
      p.CreateFolder(:name => final)
    else
      nil
    end
  end

  # Alias to +childEntity+.
  def children
    childEntity
  end

  # Efficiently retrieve properties from descendants of this folder.
  #
  # @param propSpecs [Hash] Specification of which properties to retrieve from
  #                         which entities. Keys may be symbols, strings, or
  #                         classes identifying ManagedEntity subtypes to be
  #                         included in the results. Values are an array of
  #                         property paths (strings) or the symbol :all.
  #
  # @return [Hash] Tree of inventory items. Folders are hashes from child name
  #                to child result. Objects are hashes from property path to
  #                value.
  #
  # @todo Return ObjectContent instead of the leaf hash.
  def inventory propSpecs={}
    propSet = [{ :type => 'Folder', :pathSet => ['name', 'parent'] }]
    propSpecs.each do |k,v|
      case k
      when RbVmomi::VIM::ManagedEntity
        k = k.wsdl_name
      when Symbol, String
        k = k.to_s
      else
        fail "key must be a ManagedEntity"
      end

      h = { :type => k }
      if v == :all
        h[:all] = true
      elsif v.is_a? Array
        h[:pathSet] = v + %w(parent)
      else
        fail "value must be an array of property paths or :all"
      end
      propSet << h
    end

    filterSpec = RbVmomi::VIM.PropertyFilterSpec(
      :objectSet => [
        :obj => self,
        :selectSet => [
          RbVmomi::VIM.TraversalSpec(
            :name => 'tsFolder',
            :type => 'Folder',
            :path => 'childEntity',
            :skip => false,
            :selectSet => [
              RbVmomi::VIM.SelectionSpec(:name => 'tsFolder')
            ]
          )
        ]
      ],
      :propSet => propSet
    )

    result = @soap.propertyCollector.RetrieveProperties(:specSet => [filterSpec])

    tree = { self => {} }
    result.each do |x|
      obj = x.obj
      next if obj == self
      h = Hash[x.propSet.map { |y| [y.name, y.val] }]
      tree[h['parent']][h['name']] = [obj, h]
      tree[obj] = {} if obj.is_a? RbVmomi::VIM::Folder
    end
    tree
  end
end

class RbVmomi::VIM::PropertyCollector
  def collectMultiple objs, *pathSet
    return {} if objs.empty?

    klasses = objs.map{|x| x.class}.uniq 
    klass = if klasses.length > 1
      # common superclass
      klasses.map(&:ancestors).inject(&:&)[0]
    else
      klasses.first
    end

    spec = {
      :objectSet => objs.map{|x| { :obj => x }},
      :propSet => [{
        :pathSet => pathSet,
        :type => klass.wsdl_name
      }]
    }
    res = RetrieveProperties(:specSet => [spec])
    Hash[res.map do |x|
      [x.obj, x.to_hash]
    end]
  end
  
  def pathsOfMany objs
    i = 0
    filterSpec = RbVmomi::VIM.PropertyFilterSpec(
      :objectSet => objs.map do |obj|
        i += 1
        RbVmomi::VIM.ObjectSpec(
          :obj => obj,
          :selectSet => [
            RbVmomi::VIM.TraversalSpec(
              :name => "tsME-#{i}",
              :type => 'ManagedEntity',
              :path => 'parent',
              :skip => false,
              :selectSet => [
                RbVmomi::VIM.SelectionSpec(:name => "tsME-#{i}")
              ]
            )
          ]
        )
      end,
      :propSet => [{
        :pathSet => %w(name parent),
        :type => 'ManagedEntity'
      }]
    )

    result = self.RetrieveProperties(:specSet => [filterSpec])

    Hash[objs.map do |obj|
      tree = {}
      result.each { |x| tree[x.obj] = [x['parent'], x['name']] }
      a = []
      cur = obj
      while cur
        parent, name = *tree[cur]
        a << [cur, name]
        cur = parent
      end
      [obj, a.reverse]
    end]
  end
end

class RbVmomi::VIM::ObjectContent
  def [](k)
    to_hash[k]
  end

  def to_hash
    @cached_hash ||= to_hash_uncached
  end

  private

  def to_hash_uncached
    h = {}
    propSet.each do |x|
      fail if h.member? x.name
      h[x.name] = x.val
    end
    h
  end
end

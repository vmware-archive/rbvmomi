%w(deserialization deserialization emit_request parse_response exceptions).each do |x|
  require "test_#{x}"
end

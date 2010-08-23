%w(deserialization deserialization emit_request parse_response).each do |x|
  require "test_#{x}"
end

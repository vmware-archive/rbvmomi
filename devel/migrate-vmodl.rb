#!/usr/bin/env ruby
# Migrate vmodl.db from marchal db to yaml format 
require 'yaml'

input_vmodl_filename = ARGV[0] or abort "input vmodl filename required"
output_vmodl_filename = ARGV[1] or abort "output vmodl filename required"

input_vmodl = case File.extname(input_vmodl_filename)
  when '.yml', '.yaml'
    File.open(input_vmodl_filename, 'r') { |io| YAML.load_file io }
  when '.db'
    File.open(input_vmodl_filename, 'r') { |io| Marshal.load io }
end

db = {}
tn = {}
input_vmodl.each do |k,v|
  unless k == '_typenames'
    db[k] = v
  else
    tn['_typenames'] = v
  end
end

db['_typenames'] = tn

case File.extname(output_vmodl_filename)
  when '.yml', '.yaml'
    File.open(output_vmodl_filename, 'w') { |io| YAML::dump(input_vmodl, io) }
  when '.db'
    File.open(output_vmodl_filename, 'w') { |io| Marshal.dump(input_vmodl, io) }
end

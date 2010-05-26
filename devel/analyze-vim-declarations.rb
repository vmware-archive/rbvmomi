require 'nokogiri'
require 'gdbm'

XML_FN = ARGV[0] or abort "must specify path to vim-declarations.xml"
OUT_FN = ARGV[1] or abort "must specify path to output database"

abort "given XML file does not exist" unless File.exists? XML_FN

xml = Nokogiri.parse File.read(XML_FN), nil, nil, Nokogiri::XML::ParseOptions::NOBLANKS
db = GDBM.new OUT_FN, 0666, GDBM::NEWDB
TYPES = {}

ID2NAME = Hash.new { |h,k| fail "unknown type-id #{k.inspect}" }

ID2NAME.merge!({
  'java.lang.String' => 'xsd:string',
  'BOOLEAN' => 'xsd:boolean',
  'BYTE' => 'xsd:byte',
  'SHORT' => 'xsd:short',
  'INT' => 'xsd:int',
  'LONG' => 'xsd:long',
  'FLOAT' => 'xsd:float',
  'DOUBLE' => 'xsd:double',
  'vmodl.DateTime' => 'xsd:dateTime',
  'vmodl.Any' => 'xsd:anyType',
  'void' => nil,
})

%w(DataObject ManagedObject MethodFault MethodName
   PropertyPath RuntimeFault TypeName).each do |x|
  ID2NAME['vmodl.' + x] = x
end

def handle_data_object node
  ID2NAME[node['type-id']] = node['name']
  TYPES[node['name']] = {
    'kind' => 'data',
    'base-type-id' => node['base-type-id'],
    'props' => node.children.select { |x| x.name == 'property' }.map do |property|
      {
        'name' => property['name'],
        'type-id-ref' => property['type-id-ref'],
        'is-optional' => property['is-optional'] ? true : false,
        'is-array' => property['is-array'] ? true : false,
        'version-id-ref' => property['version-id-ref'],
      }
    end
  }
end

def handle_managed_object node
  ID2NAME[node['type-id']] = node['name']
  TYPES[node['name']] = {
    'kind' => 'managed',
    'base-type-id' => node['base-type-id'],
    'props' => node.children.select { |x| x.name == 'property' }.map do |property|
      {
        'name' => property['name'],
        'type-id-ref' => property['type-id-ref'],
        'is-optional' => property['is-optional'] ? true : false,
        'is-array' => property['is-array'] ? true : false,
        'version-id-ref' => property['version-id-ref'],
      }
    end,
    'methods' => Hash[
      node.children.select { |x| x.name == 'method' }.map do |method|
        [method['is-task'] ? "#{method['name']}_Task" : method['name'],
         {
           'params' => method.children.select { |x| x.name == 'parameter' }.map do |param|
             {
               'name' => param['name'],
               'type-id-ref' => param['type-id-ref'],
               'is-array' => param['is-array'] ? true : false,
               'is-optional' => param['is-optional'] ? true : false,
               'version-id-ref' => param['version-id-ref'],
             }
           end,
           'result' => {
             'type-id-ref' => method['type-id-ref'],
             'is-array' => method['is-array'] ? true : false,
             'is-optional' => method['is-optional'] ? true : false,
             'is-task' => method['is-task'] ? true : false,
             'version-id-ref' => method['version-id-ref'],
           }
         }
        ]
      end
    ]
  }
end

def handle_enum node
  ID2NAME[node['type-id']] = node['name']
  TYPES[node['name']] = {
    'kind' => 'enum',
    'values' => node.children.map { |child| child['name'] },
  }
end

def handle_fault node
  handle_data_object node
end

xml.root.at('enums').children.each { |x| handle_enum x }
xml.root.at('managed-objects').children.each { |x| handle_managed_object x }
xml.root.at('data-objects').children.each { |x| handle_data_object x }
xml.root.at('faults').children.each { |x| handle_fault x }

munge_fault = lambda { |x| true }

TYPES.each do |k,t|
  case t['kind']
  when 'data'
    t['wsdl_base'] = t['base-type-id'] ? ID2NAME[t['base-type-id']] : 'DataObject'
    t.delete 'base-type-id'
    t['props'].each do |x|
      x['wsdl_type'] = ID2NAME[x['type-id-ref']]
      t.delete 'type-id-ref'
      munge_fault[x]
    end
  when 'managed'
    t['wsdl_base'] = t['base-type-id'] ? ID2NAME[t['base-type-id']] : 'ManagedObject'
    t.delete 'base-type-id'
    t['props'].each do |x|
      t['wsdl_type'] = ID2NAME[x['type-id-ref']]
      t.delete 'type-id-ref'
      munge_fault[x]
    end
    t['methods'].each do |mName,x|
      if y = x['result']
        y['wsdl_type'] = ID2NAME[y['type-id-ref']]
        y.delete 'type-id-ref'
        munge_fault[y]
      end
      x['params'].each do |r|
        r['wsdl_type'] = ID2NAME[r['type-id-ref']]
        r.delete 'type-id-ref'
        munge_fault[r]
      end
    end
  when 'enum'
  else fail
  end
end

TYPES.each do |k,t|
  db[k] = Marshal.dump t
end

db['_typenames'] = Marshal.dump TYPES.keys

db.close

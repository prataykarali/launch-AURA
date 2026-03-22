void main(){
  var map_name= {
    'k1':'v1', 'k2': 2, 'k3':4.5, 'k4':true
  };

  map_name['k1']='AURA';

  print(map_name['k1']);

  var nope = {};
  nope['name']= "ARIA";
  nope['Time']=3;
  print(nope);
  print(nope.isEmpty);
  print(nope.entries);
  print(nope.containsKey('name'));
  print(nope.containsValue(false));
  print(nope.remove('Time'));
  print(nope);

}
//Null key pointer
//case sensative keys
//can override
//map()={}
// var nope = {};
//   nope['name']= "ARIA";, Can be used for runtime Mapping
//used in JSON, API, Dynamic App
//eg: used in user login


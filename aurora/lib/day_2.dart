main(){
  var list=[10,20,30,50];
  list.add(30);
  var  names = [];
  names.add("AURA");
  // names.addAll(list);
  // names.insert(2,"Aria");
  names.add("Aria");
  names.insertAll(1,list);
  names[4]="Atlas";
  print("List: $names");
  names.replaceRange(0,2,[1,2,3,4]);
  print("List: $names");
  // names.removeLast();
  // names.remove(10);
  // names.removeAt(1);
  names.removeRange(0,2);
  print("List: $names");
  // print("Length: ${names.length}");
  // print("First: ${names.first}");
  // print("Rev: ${names.reversed}");
  // print("Empty: ${names.isEmpty}");
  // print("2nd: ${names.elementAt(3)}");

}
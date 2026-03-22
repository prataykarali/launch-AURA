import 'package:flutter/material.dart';
void main(){
  runApp(const Aura());
}
class Aura extends StatelessWidget{
  const Aura({super.key});
  @override
  Widget build(BuildContext context){
    return MaterialApp(
      title: 'AURA NOTEBOOK',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
        useMaterial3: true,
      ),

      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHome();
}
  class _MyHome extends State<MyHomePage>{
  late final ScrollController _myController = ScrollController();
  @override
  Widget build(BuildContext context) {
    var arrNames = ['A','B','C','D','E','F'];
    return Scaffold(
      appBar: AppBar(
          centerTitle: true,
          backgroundColor: Colors.teal,
          title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Text('A', style: TextStyle(
                    color: Colors.black87, fontWeight: FontWeight.bold)),
                Text('B', style: TextStyle(
                    color: Colors.black87, fontWeight: FontWeight.bold)),
                Text('C', style: TextStyle(
                    color: Colors.black87, fontWeight: FontWeight.bold))
              ]
          )

      ),
      body: Scrollbar(
        controller: _myController,
        interactive: true,
        thumbVisibility: true,
        thickness: 8.0,
        radius: const Radius.circular(20),
        child: ListView.separated(controller:_myController,itemBuilder: (context,index){
          return ListTile(
            leading: Text('${index+1}'),
            title:Text(arrNames[index], style: TextStyle(fontFamily: 'AURA_FONT'),),
            subtitle:Text('Id'),
            trailing: Text('User'),
          );
        },
          itemCount: arrNames.length,
          separatorBuilder: (context, index){
          return Divider(height:100, thickness: 4);
          },
        ),
      )
    );
  }
  }
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
        body:
          // child: Container(
          //   height: 100,
          //   width: 100,
          //   child: CircleAvatar(
          Card(
            color: Colors.orange,
            elevation: 20,
            child: Container(
              height: 150,
              width: 700,
              child: Row(

                children: [

                  Padding(
                    padding: const EdgeInsets.only(left:10.0 ,right: 20.0),
                    child: CircleAvatar(
                        backgroundColor: Colors.purple,
                      minRadius: 20,
                      maxRadius: 50,
                      child: Column(
                          children: [Container(
                            height: 100,
                           width: 100,
                           child: Image.asset('Assets/images/Pixel-boy (2).png'), ),

                        ]

                      )
                      ),
                  ),
                  Text('Coder: X',style: TextStyle(fontSize: 25,color: Colors.blueGrey)),
                ],
              ),
            ),
          ),

        );
  }
}
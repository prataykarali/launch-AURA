import 'package:flutter/material.dart';
void main(){
  runApp(const aura());
}
class aura extends StatelessWidget{
  const aura({super.key});
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

class MyHomePage extends StatelessWidget{
  const MyHomePage({super.key});
  @override
  Widget build(BuildContext context){
    return Scaffold(
        appBar: AppBar(
            centerTitle: true,
            backgroundColor: Colors.teal,
            title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Text('A', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
                  Text('B', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
                  Text('C', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold))
                ]
            )

        ),
        body: SingleChildScrollView(
          child: Column(
            children:[
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    Container(
                      margin: EdgeInsets.only(right: 11,top:10),
                      height: 200,
                      width: 400,
                      color: Colors.blue,
                    ),
                    Container(
                      margin: EdgeInsets.only(right: 11,top:10),
                      height: 200,
                      width: 400,
                      color: Colors.blue,
                    ),
                    Container(
                      margin: EdgeInsets.only(right: 11,top:10),
                      height: 200,
                      width: 400,
                      color: Colors.blue,
                    ),
                    Container(
                      margin: EdgeInsets.only(right: 11,top:10),
                      height: 200,
                      width: 400,
                      color: Colors.blue,
                    ),
                    Container(
                      margin: EdgeInsets.only(right: 11,top:10),
                      height: 200,
                      width: 400,
                      color: Colors.blue,
                    ),
                  ],
                ),
              ),
              Container(
                margin: EdgeInsets.only(bottom: 11,top:10),
                height: 200,

                color: Colors.blue,
              ),
              Container(
                margin: EdgeInsets.only(bottom: 11),
                height: 200,

                color: Colors.brown,
              ),
              Container(
                margin: EdgeInsets.only(bottom: 11),
                height: 200,

                color: Colors.lightGreen,
              ),
              Container(
                margin: EdgeInsets.only(bottom: 11),
                height: 200,

                color: Colors.pink,
              )
            ]
          ),
        )
    );
  }
}
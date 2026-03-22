import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';
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
class _MyHome extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) {
    // var time=DateTime.now();
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.orange,
        title: Text('Hello'),
      ),
      body: Stack(
        children: [
          Container(
            width: 800,
            height: 500,
            color: Colors.indigo,
          ),
          Container(
            width: 500,
            height: 250,
            color: Colors.redAccent,
          )
        ],
      )
    );
  }
}
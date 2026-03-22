import 'package:flutter/material.dart';
import 'screens/screens.dart';

void main(){
  runApp(const myApp());
}
class myApp extends StatelessWidget{
  const myApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AURA NOTEBOOK',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: .fromSeed(seedColor: Colors.teal),
      ),
        home:const home(),
      );
  }
}

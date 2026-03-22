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
class _MyHome extends State<MyHomePage> {
  var name= TextEditingController();
  var email= TextEditingController();
  @override
  Widget build(BuildContext context) {

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
      body: Center(
        child: Container(
            width: 300,
            height: 1000,
            child: Column(
              spacing: 25.0,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextField(


                  controller: name,
                  decoration: InputDecoration(
                      hintText: "Enter your name",
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide(
                        color: Colors.orange,
                          width: 3
                      )
                    ),
                      enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide(
                        color: Colors.orangeAccent,

                      )
                  ),
                     disabledBorder: OutlineInputBorder(
                         borderRadius: BorderRadius.circular(30),
                         borderSide: BorderSide(
                           color: Colors.blue,

                         )
                     ),
                    // suffixText: "Enter your name",
                    suffixIcon: IconButton(
                      icon: Icon(Icons.east_sharp,color: Colors.greenAccent,),
                      onPressed: (){

                      },
                    ),
                    prefixIcon: Icon(Icons.water_damage_outlined)
                  ),

                ),
            TextField(
              controller: email,
              obscureText: true,
              decoration: InputDecoration(
                  hintText: "Enter your email",
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide(
                          color: Colors.orange,
                          width: 3
                      )
                  ),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide(
                        color: Colors.orangeAccent,

                      )
                  ),
                  disabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide(
                        color: Colors.blue,

                      )
                  ),
                  // suffixText: "Enter your email",
                  suffixIcon: IconButton(
                    icon: Icon(Icons.east_sharp,color: Colors.greenAccent,),
                    onPressed: (){

                    },
                  ),
                  prefixIcon: Icon(Icons.water_damage_outlined)
              ),),
              ElevatedButton(onPressed: (){
                  String uname=name.text.toString();
                  String mail=email.text;
                  print("Email: $mail, name: $uname ");
              }, child: Text('Login'))
              ],
            )
        ),
      ),
    );
  }
}
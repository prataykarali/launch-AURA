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
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'WELCOME 🤭',
              style: TextStyle(
                fontSize: 30,
                color: Colors.green,
                fontWeight: FontWeight.bold,
                fontFamily: 'AURA FONT'
              ),
            ),
            Center( // Removed Expanded
              child: Container(
                color: Colors.lightBlueAccent,
                width: 400,
                height: 400, // Increased height slightly to fit the image inside
                child: InkWell(
                  onTap: (){
                    print('Box tapped');
                  },
                  onLongPress: (){
                    print('Longpressed ...');
                  },
                  child: Column(
                  children: [
                    Text("Hello AURA"),
                    TextButton(
                      child: Text('Click me'),
                      onPressed: () {
                        print('Text Button clicked');
                      },
                    ),
                    // This image stays inside the blue box
                    Image.asset(
                      'Assets/images/pixar_boy.jpg',
                      height: 250, // Constrain the image height
                      fit: BoxFit.contain,
                    ),

                  ],
                ),
                )
              ),
            ),
            // Removed the second Image.asset from here
            Text('I am below the blue box!'),
          ],
        )
    );
  }
}
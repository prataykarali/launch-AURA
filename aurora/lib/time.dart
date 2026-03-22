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
        title: Text('Hello'),
      ),
      body: Center(
        child: Container(
          width: 200,
          height: 200,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Text('Current Time: ${DateFormat('yMMMMd').format(time)}',style: TextStyle(fontSize: 20),),
              Text('Select Date',style: TextStyle(fontSize: 20),),

              Padding(
                padding: const EdgeInsets.all(20.0),
                child: ElevatedButton(onPressed: () async{
                  DateTime? datePicked = await showDatePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2025));
                  if (datePicked!=null){
                    print('Date Selected: ${datePicked.day}-${datePicked.month}-${datePicked.year}');
                  }
                },
                  child: Text('Show'),
                ),
              ),
              ElevatedButton(onPressed: () async{
                TimeOfDay? pickedTime= await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.now(),
                    initialEntryMode: TimePickerEntryMode.input,);
                if (pickedTime!=null){
                  print('Picked Time: ${pickedTime.hour}:${pickedTime.minute}');
                }

              }, child: Text('Select time'))
            ],
          ),
        ),
      ),
    );
  }
}
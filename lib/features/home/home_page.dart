import 'package:flutter/material.dart';


class HomePage extends StatelessWidget {

  const HomePage({super.key});


  @override
  Widget build(BuildContext context) {


    return Scaffold(

      body: Center(

        child: Column(

          mainAxisAlignment:
          MainAxisAlignment.center,


          children: [


            const Icon(
              Icons.local_library,
              size:80,
            ),


            const SizedBox(height:20),


            const Text(

              "MedicalReader",

              style:TextStyle(

                fontSize:32,

                fontWeight:
                FontWeight.bold,

              ),

            ),


            const SizedBox(height:10),


            const Text(

              "Clinical Knowledge Reader",

            ),


          ],


        ),

      ),

    );


  }

}
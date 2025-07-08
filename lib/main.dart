import 'package:flutter/material.dart';
import 'package:kur/config_service.dart';
import 'package:kur/main_page.dart';

void main() async {  
  await config.initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const MainPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

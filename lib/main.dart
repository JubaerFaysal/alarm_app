import 'package:alarm_test_final/home.dart';
import 'package:flutter/material.dart';
import 'package:alarm/alarm.dart';
import 'package:alarm_test_final/alarm_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Alarm.init();

  // Initialize the singleton alarm service
  await AlarmService().initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Alarm App',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const HomeScreen(),
    );
  }
}

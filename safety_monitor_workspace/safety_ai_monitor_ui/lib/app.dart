import 'package:flutter/material.dart';

import 'screens/home_screen.dart';

class SafetyMonitorUiApp extends StatelessWidget {
  const SafetyMonitorUiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Safety AI Monitor UI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

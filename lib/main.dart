import 'package:flutter/material.dart';
import '../screens/home_screen.dart'; // Home screen of the app

void main() {
  // Entry point of the app
  runApp(const MyApp());
}

/// Root widget of the application.
/// Uses MaterialApp with Roboto font and disables debug banner.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Image Processor App',
      home: const HomeScreen(), // Loads the main HomeScreen widget
      debugShowCheckedModeBanner: false, // Remove debug banner in production
      theme: ThemeData(
        fontFamily: 'Roboto', // Set default font family
        primarySwatch: Colors.pink, // Default primary color for Barbie theme can be set here if needed
      ),
    );
  }
}
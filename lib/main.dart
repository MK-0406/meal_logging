import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'welcome.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

final lightBlueTheme = ThemeData(
  useMaterial3: true,

  colorScheme: const ColorScheme.light(
    primary: Color(0xFF0D47A1),      // deep blue
    secondary: Color(0xFF0277BD),    // button blue
    tertiary: Color(0xFFBBDEFB),     // soft sky blue
    surface: Colors.white,
  ),

  scaffoldBackgroundColor: Color(0xFFE3F2FD),

  textTheme: const TextTheme(
    headlineLarge: TextStyle(color: Color(0xFF0D47A1)),
    headlineMedium: TextStyle(color: Color(0xFF0D47A1)),
    headlineSmall: TextStyle(color: Color(0xFF0D47A1)),
    bodyMedium: TextStyle(color: Colors.black87),
  ),

  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: Color(0xFF0277BD),
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(30)),
      ),
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 20),
    ),
  ),

  iconTheme: IconThemeData(
    color: Color(0xFF0D47A1)
  ),

);


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Meal App',
      theme: lightBlueTheme,
      home: WelcomeScreen(),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.0)),
          child: child!,
        );
      },
    );
  }
}

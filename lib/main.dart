import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'registro_screen.dart';
import 'principal_screen.dart';

// cd "C:\Users\Yoshire1Up\Documents\1. Programacion\Desarrollo Web Profe David\1._evaluacion_parcial _2\movil\litzor_movil"
// flutter run -d edge

void main() => runApp(const LitzorMovil());

class LitzorMovil extends StatelessWidget {
  const LitzorMovil({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Litzor Mobile',
      initialRoute: '/home',
      routes: {
        '/home': (context) => const HomeScreen(),
        '/login': (context) => const LoginScreen(),
        '/registro': (context) => const RegistroScreen(),
      },
    );
  }
}

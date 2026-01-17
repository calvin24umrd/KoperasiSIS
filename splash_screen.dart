// splash_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 3), () {
      if (mounted) Navigator.pushReplacementNamed(context, '/');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF8B5CF6), Color(0xFFC4B5FD)],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Pastikan nama file sesuai dengan yang ada di folder assets
            Image.asset('assets/images/splash_logo.png', width: 4500, height: 150,
              errorBuilder: (ctx, err, stack) => const Icon(Icons.diversity_3, size: 100, color: Color.fromARGB(255, 0, 0, 0))),
            const SizedBox(height: 20),
            const Text("COOPCONNECT", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 3, color: Color.fromARGB(255, 210, 165, 245))),
          ],
        ),
      ),
    );
  }
}
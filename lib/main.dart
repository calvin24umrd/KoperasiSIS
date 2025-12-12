import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:device_preview/device_preview.dart';
import 'auth_service.dart';
import 'splash_screen.dart';
import 'welcome_screen.dart';
import 'login_screen.dart';
import 'register_screen.dart';
import 'admin_dashboard.dart';
import 'member_dashboard.dart';
import 'surveyor_dashboard.dart';
import 'loan_application.dart';
import 'profile_screen.dart';

void main() {
  runApp(DevicePreview(builder: (context) => MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => AuthService()..autoLogin(),
      child: MaterialApp(
        title: 'CoopConnect',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.deepPurple,
          primaryColor: const Color(0xFF8B5CF6),
          scaffoldBackgroundColor: const Color(0xFFF3E8FF),
          useMaterial3: true,
          fontFamily: 'Roboto',
        ),
        // JANGAN PAKAI "home:", PAKAI "initialRoute"
        initialRoute: '/splash', 
        routes: {
          '/splash': (context) => const SplashScreen(),
          '/': (context) => const AuthWrapper(),
          '/welcome': (context) => const WelcomeScreen(),
          '/login': (context) => const LoginScreen(),
          '/register': (context) => const RegisterScreen(),
          '/member': (context) => const MemberDashboard(),
          '/admin': (context) => const AdminDashboard(),
          '/surveyor': (context) => const SurveyorDashboard(),
          '/loan-application': (context) => const LoanApplication(),
          '/profile': (context) => const ProfileScreen(),
        },
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);

    if (auth.isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (auth.currentUser == null) return const WelcomeScreen();

    final role = auth.currentUser!.role;
    if (role == 'admin') return const AdminDashboard();
    if (role == 'surveyor') return const SurveyorDashboard();
    return const MemberDashboard();
  }
}
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart'; // 👈 add this
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/home_shell.dart';

// 👇 add this top-level handler (must be a top-level or static function)
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If you need to do something when a notification arrives in background/terminated
  // print('BG msg: ${message.messageId}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // 👇 register background handler BEFORE runApp
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // (optional) iOS: show alerts/badges/sounds when app is in foreground
  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );

  runApp(const DriverApp());
}

class DriverApp extends StatelessWidget {
  const DriverApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MedRent Driver',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0B5CFF)),
        useMaterial3: true,
      ),
      routes: {
        '/': (_) => const LoginScreen(),
        '/home': (_) => const HomeShell(),
      },
      initialRoute: '/',
      debugShowCheckedModeBanner: false,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/home_shell.dart';

// 🔔 Background FCM handler (must be a top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If you need Firebase features in background, ensure it's initialized
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // print / handle message if needed
}

// Single instance for local notifications
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Initialize Firebase (needed for Storage / Firestore / Messaging)
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // ✅ Register background message handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // ---------- ANDROID CHANNEL WITH CUSTOM SOUND ----------
  const AndroidNotificationChannel urgentChannel = AndroidNotificationChannel(
    'urgent_delivery_channel', // MUST match channelId in your Cloud Function
    'Urgent Delivery Alerts',
    description: 'High-priority delivery assignment notifications.',
    importance: Importance.max,
    sound: RawResourceAndroidNotificationSound('urgent_delivery'), // raw/urgent_delivery.mp3
  );

  // Create notification channel (Android)
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(urgentChannel);

  // iOS: show alerts in foreground
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

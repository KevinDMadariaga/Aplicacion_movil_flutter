import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:taxi_app/screens/login.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Instancia global del plugin de notificaciones
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Inicialización para Android
  const AndroidInitializationSettings androidInitSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

  // Inicialización general
  final InitializationSettings initSettings = InitializationSettings(
    android: androidInitSettings,
  );

  // Inicializa el plugin
  await flutterLocalNotificationsPlugin.initialize(initSettings);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Taxi Ya',
      home: const LoadingScreen(),
    );
  }
}

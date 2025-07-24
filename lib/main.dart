import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_background/flutter_background.dart';
import 'package:geolocator/geolocator.dart';
import 'package:taxi_app/screens/login.dart'; // Asegúrate de tener el archivo correcto
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

// Instancia global del plugin de notificaciones
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeFirebase();
  await initializeBackgroundServices();
  await requestPermissions();
  await initializeNotifications();

  runApp(const MyApp());
}

// Función para inicializar Firebase
Future<void> initializeFirebase() async {
  try {
    await Firebase.initializeApp();
    print("Firebase Initialized Successfully");
  } catch (e) {
    print("Error initializing Firebase: $e");
    throw Exception("Error initializing Firebase");
  }
}

// Función para inicializar servicios en segundo plano
Future<void> initializeBackgroundServices() async {
  bool success = await FlutterBackground.initialize();
  if (success) {
    print("FlutterBackground initialized successfully");
    await enableBackgroundExecution();
  } else {
    print("Error initializing FlutterBackground");
  }
}

// Habilitar ejecución en segundo plano
Future<void> enableBackgroundExecution() async {
  bool success = await FlutterBackground.enableBackgroundExecution();
  if (success) {
    print("Background execution enabled");
  } else {
    print("Error enabling background execution");
  }
}

// Solicitar permisos de ubicación y notificaciones
Future<void> requestPermissions() async {
  final notificationPermission = await Permission.notification.request();
  if (notificationPermission.isGranted) {
    print("Notification permission granted");
  } else {
    print("Notification permission not granted");
  }

  final locationPermission = await Permission.locationWhenInUse.request();
  if (locationPermission.isGranted) {
    print("Location permission granted");
  } else {
    print("Location permission not granted");
  }
}

// Inicialización de notificaciones locales
Future<void> initializeNotifications() async {
  const AndroidInitializationSettings androidInitSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initSettings = InitializationSettings(
    android: androidInitSettings,
  );
  await flutterLocalNotificationsPlugin.initialize(initSettings);
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, // Desactiva el banner de debug
      title: 'Taxi Ya', // Título de la app
      theme: ThemeData(
        primarySwatch: Colors.blue, // Aquí puedes elegir el color que desees
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home:
          const LoadingScreen(), // Asegúrate de tener un loading screen antes de la pantalla de login
    );
  }
}

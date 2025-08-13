import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_background/flutter_background.dart';
import 'package:geolocator/geolocator.dart';
import 'package:taxi_app/screens/home.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';


// Instancia global del plugin de notificaciones
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Manejo de errores global en Flutter
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    // Puedes enviar los errores a Crashlytics aquí si lo deseas
  };

  // Inicializa Firebase
  try {
    await Firebase.initializeApp();
    print("Firebase Initialized Successfully");
  } catch (e) {
    print("Error initializing Firebase: $e");
    return; // Si Firebase no se inicializa, la app no debería continuar.
  }
   // Solicitar permisos para notificaciones en iOS y Android
  await _requestPermissions();

    // Inicialización de FlutterBackground antes de habilitar ejecución en segundo plano
  await _initializeBackgroundExecution();

  // Inicialización para Android de las notificaciones
  const AndroidInitializationSettings androidInitSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  // Inicialización general para la configuración de la app
  final InitializationSettings initSettings = InitializationSettings(
    android: androidInitSettings,
  );
  
  // Inicializa el plugin de notificaciones locales
  await flutterLocalNotificationsPlugin.initialize(initSettings);

  runApp(const MyApp());
}

// Función para solicitar permisos
Future<void> _requestPermissions() async {
  if (await Permission.notification.request().isGranted) {
    // Si ya está concedido, no hay nada que hacer
    print("Permiso para notificaciones concedido");
  } else {
    print("Permiso para notificaciones no concedido");
  }

  if (await Permission.locationWhenInUse.request().isGranted) {
    // Si ya está concedido, no hay nada que hacer
    print("Permiso para ubicación concedido");
  } else {
    print("Permiso para ubicación no concedido");
  }

    // Solicitar permiso para geolocalización
  await _requestLocationPermission();
}

Future<void> _requestLocationPermission() async {
  LocationPermission permission = await Geolocator.requestPermission();
  if (permission == LocationPermission.denied) {
    print("Permiso de ubicación denegado");
  } else if (permission == LocationPermission.deniedForever) {
    print("Permiso de ubicación denegado permanentemente");
  }
}

Future<void> _initializeBackgroundExecution() async {
  bool success = await FlutterBackground.initialize();
  if (success) {
    print("FlutterBackground inicializado correctamente");
    await _enableBackgroundExecution(); // Llamamos a la habilitación después de la inicialización
  } else {
    print("Error al inicializar FlutterBackground");
  }
}
Future<void> _enableBackgroundExecution() async {
  bool success = await FlutterBackground.enableBackgroundExecution();
  if (success) {
    print("Ejecución en segundo plano habilitada");
  } else {
    print("Error al habilitar ejecución en segundo plano");
  }
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
          const Home(), // Asegúrate de tener un loading screen antes de la pantalla de login
    );
  }
}

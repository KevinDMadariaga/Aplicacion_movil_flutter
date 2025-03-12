import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:taxi_app/components/boton.dart';
import 'package:taxi_app/components/colores.dart';
import 'package:taxi_app/screens/conductor/mapa_conductor.dart';
import 'package:taxi_app/screens/conductor/registro_conductor.dart';

class LoginConductor extends StatefulWidget {
  const LoginConductor({super.key});

  @override
  State<LoginConductor> createState() => _LoginConductorState();
}

class _LoginConductorState extends State<LoginConductor> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Función para iniciar sesión
  Future<void> _iniciarSesion() async {
    if (_formKey.currentState!.validate()) {
      try {
        // Verificar si el correo está registrado en la tabla "conductor"
        final QuerySnapshot result = await _firestore
            .collection('conductor')
            .where('correo', isEqualTo: _emailController.text.trim())
            .get();

        if (result.docs.isEmpty) {
          // Mostrar un mensaje si el correo no está registrado
          _showDialog("Error", "Este usuario no está permitido");
          return;
        }

        UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        await saveConductorToken(userCredential.user!.uid);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Inicio de sesión exitoso")),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MapaConductor()),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error al iniciar sesión: $e")),
        );
      }
    }
  }

  // Función para guardar el token FCM de los conductores en una nueva tabla
  Future<void> saveConductorToken(String conductorId) async {
    String? token = await FirebaseMessaging.instance.getToken();

    if (token != null) {
      await FirebaseFirestore.instance.collection('tokens_conductores').doc(conductorId).set(
        {'fcm_token': token},
        SetOptions(merge: true),
      );
      print("🔹 Token FCM guardado para conductor $conductorId: $token");
    } else {
      print("⚠️ No se pudo obtener el token FCM.");
    }
  }

  // Función para mostrar un diálogo
  void _showDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15.0),
        ),
        title: Row(
          children: [
            Icon(
              Icons.info,
              color: Colors.blue,
            ),
            const SizedBox(width: 8.0),
            Text(
              title,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          message,
          style: TextStyle(fontSize: 16, color: Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "OK",
              style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Iniciar Sesión Conductor"),
        backgroundColor: Colores.amarillo,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/img/Login.jpg',
                  width: 250.0, // Ancho en píxeles
                  height: 230.0,
                ),
                const SizedBox(height: 40.0),
                TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: "Correo Electrónico",
                    prefixIcon: const Icon(Icons.email),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return "Ingrese su correo";
                    }
                    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                      return "Correo inválido";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16.0),
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: "Contraseña",
                    prefixIcon: const Icon(Icons.lock),
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return "Ingrese su contraseña";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24.0),
                CustomButton(
                  text: 'Iniciar Sesión',
                  onPressed: _iniciarSesion,
                  width:
                      MediaQuery.of(context).size.width * 0.6, // Ancho dinámico
                  height: 50, // Alto fijo
                  fontSize: 16,
                ),
                TextButton(
                  onPressed: () {
                    // Ir a la página de registro
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const RegistroConductor()),
                    );
                  },
                  child: const Text(
                    "¿No tienes cuenta? Regístrate",
                    style: TextStyle(color: Colores.amarillo),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:taxi_app/components/boton.dart';
import 'package:taxi_app/components/colores.dart';
import 'package:taxi_app/screens/conductor/mapa_conductor.dart';
import 'package:taxi_app/screens/conductor/inicio_sesion/registro_conductor.dart';

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

  Future<void> _iniciarSesion() async {
    if (_formKey.currentState!.validate()) {
      try {
        final QuerySnapshot result = await _firestore
            .collection('conductor')
            .where('correo', isEqualTo: _emailController.text.trim())
            .get();

        if (result.docs.isEmpty) {
          _showDialog("Error", "Este usuario no está permitido");
          return;
        }

        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

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

  void _showDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15.0),
        ),
        title: Row(
          children: [
            const Icon(Icons.info, color: Colors.blue),
            const SizedBox(width: 8.0),
            Text(title,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(message,
            style: const TextStyle(fontSize: 16, color: Colors.black87)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK",
                style:
                    TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;
    final fontScale = width * 0.045;

    return Scaffold(
      appBar: AppBar(
        title: Text("Conductor", style: TextStyle(fontSize: fontScale)),
        backgroundColor: Colores.amarillo,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: width * 0.08),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              SizedBox(height: height * 0.04),
              Image.asset(
                'assets/img/Login.jpg',
                width: width * 0.65,
                height: height * 0.25,
              ),
              SizedBox(height: height * 0.04),
              TextFormField(
                controller: _emailController,
                style: TextStyle(fontSize: fontScale),
                decoration: InputDecoration(
                  labelText: "Correo Electrónico",
                  labelStyle: TextStyle(fontSize: fontScale),
                  prefixIcon: const Icon(Icons.email),
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty)
                    return "Ingrese su correo";
                  if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                    return "Correo inválido";
                  }
                  return null;
                },
              ),
              SizedBox(height: height * 0.025),
              TextFormField(
                controller: _passwordController,
                style: TextStyle(fontSize: fontScale),
                decoration: InputDecoration(
                  labelText: "Contraseña",
                  labelStyle: TextStyle(fontSize: fontScale),
                  prefixIcon: const Icon(Icons.lock),
                  border: const OutlineInputBorder(),
                ),
                obscureText: true,
                validator: (value) => (value == null || value.isEmpty)
                    ? "Ingrese su contraseña"
                    : null,
              ),
              SizedBox(height: height * 0.04),
              CustomButton(
                text: 'Iniciar Sesión',
                onPressed: _iniciarSesion,
                width: width * 0.45,
                height: 50,
                fontSize: width * 0.05,
              ),
              SizedBox(height: height * 0.02),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const RegistroConductor()),
                  );
                },
                child: Text(
                  "¿No tienes cuenta? Regístrate",
                  style: TextStyle(
                      fontSize: fontScale * 0.95, color: Colores.amarillo),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:taxi_app/components/boton.dart';
import 'package:taxi_app/components/colores.dart';
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

  // Función para iniciar sesión
  Future<void> _iniciarSesion() async {
    if (_formKey.currentState!.validate()) {
      try {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Inicio de sesión exitoso")),
        );
        // Navegar a otra página después del login (reemplaza 'HomePage')
        // Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => HomePage()));
      } catch (e) {
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error al iniciar sesión: $e")),
        );
      }
    }
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

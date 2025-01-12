import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:taxi_app/screens/cliente/registro_cliente.dart';

class LoginCliente extends StatefulWidget {
  const LoginCliente({super.key});

  @override
  State<LoginCliente> createState() => _LoginClienteState();
}

class _LoginClienteState extends State<LoginCliente> {
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Inicio de sesión exitoso")),
        );
        // Navegar a otra página después del login (reemplaza 'HomePage')
        // Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => HomePage()));
      } catch (e) {
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
        title: const Text("Iniciar Sesión"),
        backgroundColor: Colors.blueAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
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
              ElevatedButton(
                onPressed: _iniciarSesion,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                ),
                child: const Text("Iniciar Sesión"),
              ),
              TextButton(
                onPressed: () {
                  // Ir a la página de registro
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const RegistroCliente()),
                  );
                },
                child: const Text(
                  "¿No tienes cuenta? Regístrate",
                  style: TextStyle(color: Colors.blueAccent),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

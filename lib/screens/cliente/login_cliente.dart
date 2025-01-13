import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:taxi_app/components/boton.dart';
import 'package:taxi_app/components/colores.dart';
import 'package:taxi_app/screens/cliente/mapa_cliente.dart';
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
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _verificarUsuarioLogueado();
  }

  // Verificar si el usuario ya está logueado
  void _verificarUsuarioLogueado() {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Redirigir al mapa si el usuario ya está autenticado
      Future.microtask(() {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MapaCliente()),
        );
      });
    }
  }

  // Función para iniciar sesión
  Future<void> _iniciarSesion() async {
    if (_formKey.currentState!.validate()) {
      try {
        // Verificar si el correo está registrado en la tabla "cliente"
        final QuerySnapshot result = await _firestore
            .collection('cliente')
            .where('correo', isEqualTo: _emailController.text.trim())
            .get();

        if (result.docs.isEmpty) {
          // Mostrar un mensaje si el correo no está registrado
          _showDialog("Error", "Este usuario no está permitido");
          return;
        }

        // Si el correo está registrado, intentar iniciar sesión
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Inicio de sesión exitoso")),
        );

        // Navegar a la pantalla del mapa
        // ignore: use_build_context_synchronously
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MapaCliente()),
        );
      } catch (e) {
        // Mostrar mensaje de error en caso de excepción
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error al iniciar sesión: $e")),
        );
      }
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
        title: const Text("Iniciar Sesión Cliente"),
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
                  width: 202, // Ancho del botón
                  height: 50, // Alto del botón
                  fontSize: 16, // Tamaño de fuente del texto
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

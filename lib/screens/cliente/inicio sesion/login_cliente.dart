import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:taxi_app/components/boton.dart';
import 'package:taxi_app/components/colores.dart';
import 'package:taxi_app/screens/cliente/mapa_cliente.dart';
import 'package:taxi_app/screens/cliente/inicio%20sesion/registro_cliente.dart';

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

  void _verificarUsuarioLogueado() {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      Future.microtask(() {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MapaCliente()),
        );
      });
    }
  }

  Future<void> _iniciarSesion() async {
    if (_formKey.currentState!.validate()) {
      try {
        final QuerySnapshot result = await _firestore
            .collection('cliente')
            .where('correo', isEqualTo: _emailController.text.trim())
            .get();

        if (result.docs.isEmpty) {
          if (!mounted) return;
          _showDialog("Error", "Este usuario no está permitido");
          return;
        }

        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        if (!mounted) return;

        // Mostrar diálogo con animación fade
        await Navigator.of(context).push(_createFadeDialog());

        // Ir a la pantalla principal
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MapaCliente()),
        );
      } catch (e) {
        if (!mounted) return;
        _showDialog("Error", "Error al iniciar sesión: $e");
      }
    }
  }

  PageRouteBuilder _createFadeDialog() {
    return PageRouteBuilder(
      opaque: false,
      barrierDismissible: false,
      pageBuilder: (context, animation, secondaryAnimation) {
        Future.delayed(const Duration(seconds: 1), () {
          Navigator.of(context).pop(); // Cierra el diálogo automáticamente
        });

        return FadeTransition(
          opacity: animation,
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                content: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.check_circle, color: Colors.green),
                    SizedBox(width: 10),
                    Text(
                      "Inicio de sesión exitoso",
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    );
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
            Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 16),
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
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Cliente"),
        backgroundColor: Colores.amarillo,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: width * 0.08),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                SizedBox(height: height * 0.05),
                Image.asset(
                  'assets/img/Login.jpg',
                  width: width * 0.7,
                  height: height * 0.25,
                  fit: BoxFit.contain,
                ),
                SizedBox(height: height * 0.05),
                TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: "Correo Electrónico",
                    prefixIcon: const Icon(Icons.email),
                    border: const OutlineInputBorder(),
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
                SizedBox(height: height * 0.02),
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: "Contraseña",
                    prefixIcon: const Icon(Icons.lock),
                    border: const OutlineInputBorder(),
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return "Ingrese su contraseña";
                    }
                    return null;
                  },
                ),
                SizedBox(height: height * 0.04),
                CustomButton(
                  text: 'Iniciar Sesión',
                  onPressed: _iniciarSesion,
                  width: width * 0.45,
                  height: 50,
                  fontSize: width * 0.05,
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const RegistroCliente()),
                    );
                  },
                  child: Text(
                    "¿No tienes cuenta? Regístrate",
                    style: TextStyle(
                      color: Colores.amarillo,
                      fontSize: width * 0.038,
                      fontWeight: FontWeight.w600,
                    ),
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

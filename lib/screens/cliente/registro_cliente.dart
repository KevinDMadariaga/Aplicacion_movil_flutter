import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:taxi_app/components/colores.dart';

class RegistroCliente extends StatefulWidget {
  const RegistroCliente({super.key});

  @override
  State<RegistroCliente> createState() => _RegistroClienteState();
}

class _RegistroClienteState extends State<RegistroCliente> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nombreController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isPasswordVisible = false;

  // Función para guardar los datos en Firestore
  Future<void> _guardarDatosEnFirestore(UserCredential userCredential) async {
    await _firestore.collection("cliente").doc(userCredential.user!.uid).set({
      "clienteId": userCredential.user!.uid,
      "nombre": _nombreController.text.trim(),
      "telefono": _telefonoController.text.trim(),
      "correo": _emailController.text.trim(),
      "contraseña": _passwordController.text.trim(),
    });
  }

  // Función para registrar un nuevo usuario
  Future<void> _registrarCliente() async {
    if (_formKey.currentState!.validate()) {
      try {
        UserCredential userCredential =
            await _auth.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        await _guardarDatosEnFirestore(userCredential);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Registro exitoso")),
        );
        Navigator.pop(context); // Vuelve al login después de registrarse
      } catch (e) {
        _showDialog("Error", e.toString());
      }
    }
  }

// Mostrar un diálogo con mensajes
  void _showDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

// Validaciones centralizadas
  String? _validateCorreo(String? value) {
    if (value == null || value.isEmpty) return "Ingrese su correo";
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value))
      return "Correo inválido";
    return null;
  }

  String? _validateTelefono(String? value) {
    if (value == null || value.isEmpty) return "Ingrese su número de teléfono";
    if (!RegExp(r'^\d{10}$').hasMatch(value))
      return "Número inválido (10 dígitos)";
    return null;
  }

  String? _validateContrasena(String? value) {
    if (value == null || value.isEmpty) return "Ingrese su contraseña";
    if (value.length < 6) return "Debe tener al menos 6 caracteres";
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Registro de Cliente"),
        backgroundColor: Colores.amarillo,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            // Permite desplazar el contenido si es necesario
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Campo de Nombre
                  TextFormField(
                    controller: _nombreController,
                    decoration: InputDecoration(
                      labelText: "Nombre Completo",
                      prefixIcon: const Icon(Icons.person),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return "Ingrese su nombre completo";
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                  // Campo de Número de Teléfono
                  TextFormField(
                    controller: _telefonoController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: "Número de Teléfono",
                      prefixIcon: const Icon(Icons.phone),
                      border: OutlineInputBorder(),
                    ),
                    validator: _validateTelefono,
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: "Correo Electrónico",
                      prefixIcon: const Icon(Icons.email),
                      border: OutlineInputBorder(),
                    ),
                    validator: _validateCorreo,
                  ),
                  const SizedBox(height: 16.0),
                  // Campo de Contraseña
                  TextFormField(
                    controller: _passwordController,
                    obscureText: !_isPasswordVisible,
                    decoration: InputDecoration(
                      labelText: "Contraseña",
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isPasswordVisible
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            _isPasswordVisible = !_isPasswordVisible;
                          });
                        },
                      ),
                      border: const OutlineInputBorder(),
                    ),
                    validator: _validateContrasena,
                  ),
                  const SizedBox(height: 24.0),
                  // Campo de Confirmar Contraseña
                  // Campo de Confirmar Contraseña
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: "Confirmar Contraseña",
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: const OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return "Confirme su contraseña";
                      }
                      if (value != _passwordController.text) {
                        return "Las contraseñas no coinciden";
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24.0),
                  ElevatedButton(
                    onPressed: _registrarCliente,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colores.amarillo,
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                    ),
                    child: const Text("Registrar"),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

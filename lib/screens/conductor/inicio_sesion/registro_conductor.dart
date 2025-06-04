import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:taxi_app/components/boton.dart';
import 'package:taxi_app/components/colores.dart';
import 'package:taxi_app/screens/conductor/mapa_conductor.dart';

class RegistroConductor extends StatefulWidget {
  const RegistroConductor({super.key});

  @override
  State<RegistroConductor> createState() => _RegistroConductorState();
}

class _RegistroConductorState extends State<RegistroConductor> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nombreController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _placaController = TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isPasswordVisible = false;

  // Función para guardar los datos en Firestore
  Future<void> _guardarDatosEnFirestore(UserCredential userCredential) async {
    await _firestore.collection("conductor").doc(userCredential.user!.uid).set({
      "tipoUsuario": "conductor",
      "conductorId": userCredential.user!.uid,
      "nombre": _nombreController.text.trim(),
      "telefono": _telefonoController.text.trim(),
      "correo": _emailController.text.trim(),
      "contraseña": _passwordController.text.trim(),
      "conectado": true, // Agregar el campo 'conectado' con valor 'true'
      "placa": _placaController.text.trim(),
    });
  }

  Future<void> _registrarConductor() async {
    if (_formKey.currentState!.validate()) {
      try {
        final signInMethods = await _auth.fetchSignInMethodsForEmail(
          _emailController.text.trim(),
        );

        if (signInMethods.isNotEmpty) {
          _showDialog(
            "Error",
            "Este correo ya está registrado. Intenta con otro.",
          );
          return;
        }

        UserCredential userCredential = await _auth
            .createUserWithEmailAndPassword(
              email: _emailController.text.trim(),
              password: _passwordController.text.trim(),
            );

        await _guardarDatosEnFirestore(userCredential);

        // Mostrar mensaje de éxito en medio de la pantalla
        _showSuccessMessage();
      } on FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use') {
          _showDialog(
            "Error",
            "Este correo ya está registrado. Intenta con otro.",
          );
        } else {
          _showDialog("Error", e.message ?? "Ocurrió un error inesperado.");
        }
      } catch (e) {
        _showDialog("Error", "Ocurrió un error inesperado.");
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

  // Mostrar mensaje de éxito y redirigir
  void _showSuccessMessage() {
    // Muestra un SnackBar en lugar de un AlertDialog
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 30),
            const SizedBox(width: 10),
            const Text(
              "¡Registro exitoso! Bienvenido al sistema.",
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
        duration: const Duration(seconds: 2), // Duración del SnackBar
      ),
    );

    // Después de 2 segundos, se redirige a la pantalla de MapaConductor
    Future.delayed(const Duration(seconds: 2), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MapaConductor()),
      );
    });
  }

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
        title: const Text("Registro de Conductor"),
        backgroundColor: Colores.amarillo,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Image.asset(
                    'assets/img/taxi.png',
                    width: 200.0,
                    height: 170.0,
                  ),

                  SizedBox(height: 30),
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
                    controller: _placaController,
                    decoration: InputDecoration(
                      labelText: "Numero de Placa",
                      prefixIcon: const Icon(Icons.perm_identity),
                      border: OutlineInputBorder(),
                    ),
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
                  // Campo de Correo Electrónico
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
                  // CAMPO: Contraseña
                  TextFormField(
                    controller: _passwordController,
                    obscureText: !_isPasswordVisible,
                    onChanged: (value) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: "Contraseña",
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_passwordController.text.isNotEmpty)
                            Icon(
                              _passwordController.text.length >= 6
                                  ? Icons.check_circle
                                  : Icons.cancel,
                              color: _passwordController.text.length >= 6
                                  ? Colors.green
                                  : Colors.red,
                            ),
                          IconButton(
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
                        ],
                      ),
                      errorText:
                          _passwordController.text.isNotEmpty &&
                              _passwordController.text.length < 6
                          ? "Mínimo 6 caracteres"
                          : null,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // CAMPO: Confirmar Contraseña
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: !_isPasswordVisible,
                    onChanged: (value) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: "Confirmar Contraseña",
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: _confirmPasswordController.text.isNotEmpty
                          ? Icon(
                              _confirmPasswordController.text.length >= 6 &&
                                      _confirmPasswordController.text ==
                                          _passwordController.text
                                  ? Icons.check_circle
                                  : Icons.cancel,
                              color:
                                  _confirmPasswordController.text.length >= 6 &&
                                      _confirmPasswordController.text ==
                                          _passwordController.text
                                  ? Colors.green
                                  : Colors.red,
                            )
                          : null,
                      errorText:
                          _confirmPasswordController.text.isNotEmpty &&
                              _confirmPasswordController.text.length < 6
                          ? "Mínimo 6 caracteres"
                          : _confirmPasswordController.text !=
                                _passwordController.text
                          ? "Las contraseñas no coinciden"
                          : null,
                      border: const OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 24.0),
                  CustomButton(
                    text: 'Registrar',
                    onPressed: _registrarConductor,
                    width: 100,
                    height: 50,
                    fontSize: 16,
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

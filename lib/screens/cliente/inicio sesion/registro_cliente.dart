import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:taxi_app/components/boton.dart';
import 'package:taxi_app/components/colores.dart';
import 'package:taxi_app/screens/cliente/mapa_cliente.dart';

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
  bool _passwordValido = false;

  Future<void> _guardarDatosEnFirestore(UserCredential userCredential) async {
    await _firestore.collection("cliente").doc(userCredential.user!.uid).set({
      "tipoUsuario": "cliente",
      "clienteId": userCredential.user!.uid,
      "nombre": _nombreController.text.trim(),
      "telefono": _telefonoController.text.trim(),
      "correo": _emailController.text.trim(),
      "contraseña": _passwordController.text.trim(),
    });
  }

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

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MapaCliente()),
        );
      } catch (e) {
        _showDialog("Error", e.toString());
      }
    }
  }

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

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final fontSize = screenWidth * 0.045;

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
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Image.asset(
                    'assets/img/taxi.png',
                    width: screenWidth * 0.5,
                    height: screenHeight * 0.2,
                  ),
                  SizedBox(height: screenHeight * 0.03),

                  // Campo Nombre
                  TextFormField(
                    controller: _nombreController,
                    style: TextStyle(fontSize: fontSize),
                    decoration: InputDecoration(
                      labelText: "Nombre Completo",
                      labelStyle: TextStyle(fontSize: fontSize),
                      prefixIcon: const Icon(Icons.person),
                      border: const OutlineInputBorder(),
                    ),
                    validator: (value) => value == null || value.isEmpty
                        ? "Ingrese su nombre completo"
                        : null,
                  ),
                  SizedBox(height: screenHeight * 0.02),

                  // Campo Teléfono
                  TextFormField(
                    controller: _telefonoController,
                    keyboardType: TextInputType.phone,
                    style: TextStyle(fontSize: fontSize),
                    decoration: InputDecoration(
                      labelText: "Número de Teléfono",
                      labelStyle: TextStyle(fontSize: fontSize),
                      prefixIcon: const Icon(Icons.phone),
                      border: const OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return "Ingrese su número de teléfono";
                      }
                      if (!RegExp(r'^\d{10}$').hasMatch(value)) {
                        return "Número inválido (10 dígitos)";
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: screenHeight * 0.02),

                  // Campo Correo
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: TextStyle(fontSize: fontSize),
                    decoration: InputDecoration(
                      labelText: "Correo Electrónico",
                      labelStyle: TextStyle(fontSize: fontSize),
                      prefixIcon: const Icon(Icons.email),
                      border: const OutlineInputBorder(),
                    ),
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
                  SizedBox(height: screenHeight * 0.02),

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
                      errorText: _passwordController.text.isNotEmpty &&
                              _passwordController.text.length < 6
                          ? "Mínimo 6 caracteres"
                          : null,
                      border: OutlineInputBorder(),
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
                      errorText: _confirmPasswordController.text.isNotEmpty &&
                              _confirmPasswordController.text.length < 6
                          ? "Mínimo 6 caracteres"
                          : _confirmPasswordController.text !=
                                  _passwordController.text
                              ? "Las contraseñas no coinciden"
                              : null,
                      border: OutlineInputBorder(),
                    ),
                  ),

                  SizedBox(height: screenHeight * 0.04),
                  CustomButton(
                    text: 'Registrar',
                    onPressed: _registrarCliente,
                    width: 30,
                    height: 50,
                    fontSize: fontSize,
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

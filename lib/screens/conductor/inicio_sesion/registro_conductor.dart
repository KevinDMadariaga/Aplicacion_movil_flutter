import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:taxi_app/components/boton.dart';
import 'package:taxi_app/components/colores.dart';
import 'package:taxi_app/screens/conductor/mapa_conductor.dart';
import 'package:firebase_storage/firebase_storage.dart'; // Para subir la imagen a Firebase Storage
import 'package:image_picker/image_picker.dart'; // Para seleccionar la imagen
import 'dart:io'; // Para trabajar con archivos locales

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

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isPasswordVisible = false;
  String? _profileImageUrl; // Para almacenar la URL de la foto de perfil
  final ImagePicker _picker = ImagePicker(); // Instancia de ImagePicker

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
      "profileImageUrl":
          null, // Campo 'profileImageUrl' con valor 'null' inicialmente
    });
  }

  // Función para seleccionar una imagen y subirla a Firebase Storage
  Future<void> _pickAndUploadImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      try {
        final file = File(pickedFile.path);
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('profile_images')
            .child(FirebaseAuth.instance.currentUser!.uid + '.jpg');
        final uploadTask = storageRef.putFile(file);
        final snapshot = await uploadTask.whenComplete(() => {});
        final downloadUrl = await snapshot.ref.getDownloadURL();

        // Actualizar la URL de la imagen en Firestore
        await FirebaseFirestore.instance
            .collection('conductor')
            .doc(FirebaseAuth.instance.currentUser!.uid)
            .update({'profileImageUrl': downloadUrl});

        setState(() {
          _profileImageUrl = downloadUrl;
        });
      } catch (e) {
        print('Error al subir la imagen: $e');
      }
    }
  }

  Future<void> _registrarConductor() async {
    if (_formKey.currentState!.validate()) {
      try {
        final signInMethods = await _auth
            .fetchSignInMethodsForEmail(_emailController.text.trim());

        if (signInMethods.isNotEmpty) {
          _showDialog(
              "Error", "Este correo ya está registrado. Intenta con otro.");
          return;
        }

        UserCredential userCredential =
            await _auth.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        await _guardarDatosEnFirestore(userCredential);

        // Mostrar mensaje de éxito en medio de la pantalla
        _showSuccessMessage();
      } on FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use') {
          _showDialog(
              "Error", "Este correo ya está registrado. Intenta con otro.");
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 50,
            ),
            const SizedBox(height: 20),
            const Text(
              "¡Registro exitoso!",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            const Text("Bienvenido al sistema."),
          ],
        ),
      ),
    );

    // Después de un retraso de 2 segundos, se redirige a la pantalla de MapaConductor
    Future.delayed(const Duration(seconds: 2), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (context) =>
                const MapaConductor()), // Asegúrate de que MapaConductor esté disponible
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

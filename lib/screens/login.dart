import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:taxi_app/screens/cliente/mapa_cliente.dart';
import 'package:taxi_app/screens/conductor/mapa_conductor.dart';
import 'package:taxi_app/screens/home.dart';

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<User?>(
      future: FirebaseAuth.instance.authStateChanges().first,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData && snapshot.data != null) {
          final user = snapshot.data!;
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('cliente')
                .doc(user.uid)
                .get(),
            builder: (context, clientSnapshot) {
              if (clientSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              if (clientSnapshot.hasData && clientSnapshot.data!.exists) {
                return const MapaCliente();
              } else {
                return const MapaConductor();
              }
            },
          );
        } else {
          return const home(); // Nueva pantalla para elegir rol
        }
      },
    );
  }
}

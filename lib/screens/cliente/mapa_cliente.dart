import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:taxi_app/components/colores.dart';
import 'package:taxi_app/screens/cliente/login_cliente.dart';
import 'package:taxi_app/screens/home.dart';

class MapaCliente extends StatelessWidget {
  const MapaCliente({super.key});

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;

    // Si no hay un usuario autenticado, redirigir a la pantalla de inicio de sesión
    if (user == null) {
      Future.microtask(() {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginCliente()),
        );
      });
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colores.amarillo,
        title: Text("mapa cliente"),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            DrawerHeader(
              decoration: BoxDecoration(
                color: Colores.amarillo,
              ),
              child: Text(
                'Bienvenido, ${user?.email ?? 'Usuario'}',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.map),
              title: const Text('Ver Mapa'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Perfil'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Cerrar Sesión'),
              onTap: () async {
                try {
                  await FirebaseAuth.instance.signOut();
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const home(),
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        "Error al cerrar sesión: $e",
                        style: const TextStyle(color: Colors.white),
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
      body: const Center(
        child: Text(
          "Página Mapa Cliente",
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}

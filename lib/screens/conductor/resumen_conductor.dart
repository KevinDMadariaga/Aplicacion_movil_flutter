import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geocoding/geocoding.dart';

class ResumenConductor extends StatelessWidget {
  final String solicitudId;

  const ResumenConductor({Key? key, required this.solicitudId})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Resumen del Servicio"),
        backgroundColor: Colors.blueAccent,
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('solicitud')
            .doc(solicitudId)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(child: Text("Error al cargar los datos"));
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("No se encontraron datos"));
          }

          var solicitudData = snapshot.data!;
          var ubicacionInicial = solicitudData['ubicacion_inicial'];
          var direccionSeleccionada = solicitudData[
              'direccion_seleccionada']; // Extraemos la direccion seleccionada
          var clienteId =
              solicitudData['clienteId']; // Obtener el ID del cliente

          // Obtener el nombre del cliente
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('cliente')
                .doc(clienteId)
                .get(),
            builder: (context, clienteSnapshot) {
              if (clienteSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (clienteSnapshot.hasError) {
                return const Center(
                    child: Text("Error al cargar los datos del cliente"));
              }

              if (!clienteSnapshot.hasData || !clienteSnapshot.data!.exists) {
                return const Center(
                    child: Text("No se encontraron datos del cliente"));
              }

              var clienteData = clienteSnapshot.data!;
              var nombreCliente =
                  clienteData['nombre']; // Obtener el nombre del cliente

              // Convertir las coordenadas a dirección usando geocoding
              return FutureBuilder<List<Placemark>>(
                future: placemarkFromCoordinates(
                  ubicacionInicial.latitude,
                  ubicacionInicial.longitude,
                ),
                builder: (context, placemarksSnapshot) {
                  if (placemarksSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (placemarksSnapshot.hasError) {
                    return const Center(
                        child: Text("Error al obtener la dirección"));
                  }

                  if (!placemarksSnapshot.hasData ||
                      placemarksSnapshot.data!.isEmpty) {
                    return const Center(child: Text("Dirección no disponible"));
                  }

                  var placemark = placemarksSnapshot.data!.first;
                  String direccionRecogida =
                      "${placemark.street}, ${placemark.locality}, ${placemark.country}";

                  return Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Resumen del Servicio",
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.blueAccent,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          "👤 Cliente: ",
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          "$nombreCliente",
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 20),
                        // Cambié de "Punto de Recogida" a texto
                        Text(
                          "📍 Dirección de Recogida:",
                          style: const TextStyle(fontSize: 16),
                        ),
                        Text(
                          direccionRecogida,
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          "🏁 Dirección Seleccionada: ",
                          style: const TextStyle(fontSize: 16),
                        ),
                        Text(
                          direccionSeleccionada,
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pushReplacementNamed(context, '/home');
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            textStyle: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          child: const Text("Volver a Inicio"),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

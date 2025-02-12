import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ConductorRecogida extends StatelessWidget {
  final String clienteId;
  final GeoPoint ubicacionInicial;
  final GeoPoint ubicacionDestino;

  const ConductorRecogida({
    Key? key,
    required this.clienteId,
    required this.ubicacionInicial,
    required this.ubicacionDestino,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Recogida del Cliente")),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            "Dirígete a la ubicación del cliente",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          Text("Cliente ID: $clienteId"),
          Text(
              "Ubicación Inicial: Lat ${ubicacionInicial.latitude}, Lng ${ubicacionInicial.longitude}"),
          Text(
              "Destino: Lat ${ubicacionDestino.latitude}, Lng ${ubicacionDestino.longitude}"),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text("Finalizar Recogida"),
          ),
        ],
      ),
    );
  }
}

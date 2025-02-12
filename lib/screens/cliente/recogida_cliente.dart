import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ClienteRecogida extends StatelessWidget {
  final String conductorId;
  final GeoPoint ubicacionInicial;
  final GeoPoint ubicacionDestino;

  const ClienteRecogida({
    Key? key,
    required this.conductorId,
    required this.ubicacionInicial,
    required this.ubicacionDestino,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Conductor en camino")),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            "Un conductor ha aceptado tu solicitud",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          Text("Conductor ID: $conductorId"),
          Text("Ubicación Inicial: Lat ${ubicacionInicial.latitude}, Lng ${ubicacionInicial.longitude}"),
          Text("Destino: Lat ${ubicacionDestino.latitude}, Lng ${ubicacionDestino.longitude}"),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text("Finalizar Viaje"),
          ),
        ],
      ),
    );
  }
}

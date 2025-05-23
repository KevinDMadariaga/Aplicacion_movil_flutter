import 'package:flutter/material.dart';

class DetalleViajeConductor extends StatelessWidget {
  final Map<String, dynamic> data;

  const DetalleViajeConductor({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Detalle del Viaje"),
        backgroundColor: Colors.amber,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            const Text("Detalles del viaje:",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text("Cliente: ${data['cliente_nombre'] ?? 'N/A'}"),
            Text("Conductor: ${data['conductor_nombre'] ?? 'N/A'}"),
            Text("Dirección inicial: ${data['direccion_inicial'].toString()}"),
            Text("Dirección destino: ${data['direccion_destino'] ?? 'N/A'}"),
            Text("Solicitud ID: ${data['solicitudId'] ?? 'N/A'}"),
            Text(
                "Duración: ${data['duracion_minutos']?.toString() ?? '0'} minutos"),
            Text(
                "Calificación: ${data['calificacion']?.toString() ?? 'No calificado'}"),
          ],
        ),
      ),
    );
  }
}

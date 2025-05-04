import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class DetallesViaje extends StatelessWidget {
  final String solicitudId;

  const DetallesViaje({Key? key, required this.solicitudId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalles del Viaje'),
        backgroundColor: Colors.blueAccent,
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection(
                'historial viaje') // Asegúrate de que la colección es correcta
            .doc(
                solicitudId) // Traemos los detalles de la solicitud usando el ID
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(child: Text("Error al cargar los detalles"));
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("Detalles no disponibles"));
          }

          var historialData = snapshot.data!.data() as Map<String, dynamic>;
          var clienteId = historialData['clienteId'];
          var direccionSeleccionada = historialData['direccion_seleccionada'];
          var estado = historialData['estado'];
          var fechaCreacion = historialData['fecha_creacion']?.toDate();
          var ubicacionInicial = historialData['ubicacion_inicial'];
          var ubicacionDestino = historialData['ubicacion_seleccionada'];
          var horaAceptacion = historialData['hora_aceptacion']?.toDate();
          var horaTerminacion = historialData['hora_terminacion']?.toDate();

          // Calculamos la duración del servicio
          String duracionServicio = "";
          if (horaAceptacion != null && horaTerminacion != null) {
            final duracion = horaTerminacion.difference(horaAceptacion);
            duracionServicio = "${duracion.inMinutes} minutos";
          }

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cliente: $clienteId',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Text('Estado: $estado', style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 10),
                Text('Destino: $direccionSeleccionada',
                    style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 10),
                Text(
                    'Fecha del Viaje: ${fechaCreacion != null ? fechaCreacion.toString() : "N/A"}',
                    style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 10),
                Text('Ubicación de Recogida: $ubicacionInicial',
                    style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 10),
                Text('Ubicación de Destino: $ubicacionDestino',
                    style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 10),
                Text(
                    'Hora de Aceptación: ${horaAceptacion != null ? horaAceptacion.toString() : "N/A"}',
                    style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 10),
                Text(
                    'Hora de Terminación: ${horaTerminacion != null ? horaTerminacion.toString() : "N/A"}',
                    style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 10),
                Text('Duración del Servicio: $duracionServicio',
                    style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('Volver'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

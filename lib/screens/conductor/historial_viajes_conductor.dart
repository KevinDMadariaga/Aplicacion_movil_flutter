import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geocoding/geocoding.dart';

class HistorialConductor extends StatelessWidget {
  const HistorialConductor({super.key});

  String formatoFechaHora(Timestamp timestamp) {
    final fecha = timestamp.toDate().toUtc().subtract(const Duration(hours: 5));
    return "${fecha.day.toString().padLeft(2, '0')}/"
        "${fecha.month.toString().padLeft(2, '0')}/"
        "${fecha.year} ${fecha.hour.toString().padLeft(2, '0')}:"
        "${fecha.minute.toString().padLeft(2, '0')}";
  }

  Future<String> obtenerDireccion(dynamic ubicacion) async {
    if (ubicacion is GeoPoint) {
      try {
        final placemarks = await placemarkFromCoordinates(
          ubicacion.latitude,
          ubicacion.longitude,
        );
        final p = placemarks.first;
        return "${p.street ?? ''}, ${p.locality ?? ''}";
      } catch (_) {
        return "Dirección no disponible";
      }
    } else if (ubicacion is String) {
      return ubicacion;
    } else {
      return "Origen desconocido";
    }
  }

  void mostrarDetalle(BuildContext context, Map<String, dynamic> data) async {
    final screenWidth = MediaQuery.of(context).size.width;
    final baseFontSize = screenWidth * 0.042;

    final origen = await obtenerDireccion(data['direccion_inicial']);
    final destino = data['direccion_destino'] ?? 'Destino no disponible';
    final horaInicio = data['hora_aceptacion'] as Timestamp?;
    final horaFin = data['fecha_termino'] as Timestamp?;
    final duracion = data['duracion_minutos'] ?? '-';
    final calificacionNum = data['calificacion'] ?? 0;
    final cliente = data['cliente_nombre'] ?? 'Cliente';

    final calificacionTexto = {
          1: "😡 Mala",
          2: "🙂 Buena",
          3: "😍 Excelente"
        }[calificacionNum] ??
        "Sin calificación";

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Center(
          child: Text(
            "📝 Detalle del Viaje",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: baseFontSize + 2,
            ),
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("👤 Cliente: $cliente",
                  style: TextStyle(fontSize: baseFontSize)),
              const SizedBox(height: 8),
              Text("📍 Origen: $origen",
                  style: TextStyle(fontSize: baseFontSize)),
              const SizedBox(height: 8),
              Text("🏁 Destino: $destino",
                  style: TextStyle(fontSize: baseFontSize)),
              const SizedBox(height: 8),
              if (horaInicio != null)
                Text("🕓 Inicio: ${formatoFechaHora(horaInicio)}",
                    style: TextStyle(fontSize: baseFontSize)),
              if (horaFin != null)
                Text("🏁 Fin: ${formatoFechaHora(horaFin)}",
                    style: TextStyle(fontSize: baseFontSize)),
              const SizedBox(height: 8),
              Text("⏱ Duración: $duracion min",
                  style: TextStyle(fontSize: baseFontSize)),
              const SizedBox(height: 8),
              Text("⭐ Calificación: $calificacionTexto",
                  style: TextStyle(fontSize: baseFontSize)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "Cerrar",
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: baseFontSize,
                color: Theme.of(context).primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String conductorId = FirebaseAuth.instance.currentUser?.uid ?? "";

    return Scaffold(
      appBar: AppBar(
        title: const Text("Historial de Viajes"),
        backgroundColor: Colors.amber,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('historial viaje')
            .where('conductorId', isEqualTo: conductorId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text("Error al cargar los datos."));
          }

          final viajes = snapshot.data?.docs ?? [];

          if (viajes.isEmpty) {
            return const Center(child: Text("No hay viajes registrados."));
          }

          return ListView.builder(
            itemCount: viajes.length,
            itemBuilder: (context, index) {
              final data = viajes[index].data() as Map<String, dynamic>;

              final destino = data['direccion_destino'] ?? 'Destino';
              final horaFin = data['fecha_termino'] as Timestamp?;
              final duracion = data['duracion_minutos']?.toString() ?? '-';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: ListTile(
                  leading: const Icon(Icons.local_taxi, color: Colors.amber),
                  title: Text("$destino"),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (horaFin != null)
                        Text("📅 Finalizado: ${formatoFechaHora(horaFin)}"),
                      Text("⏱ Duración: $duracion min"),
                    ],
                  ),
                  onTap: () => mostrarDetalle(context, data),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

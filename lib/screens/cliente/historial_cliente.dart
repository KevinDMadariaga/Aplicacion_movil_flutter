import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geocoding/geocoding.dart';

class HistorialCliente extends StatelessWidget {
  const HistorialCliente({super.key});

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

    String origen = "Origen desconocido";
    try {
      origen = await obtenerDireccion(data['direccion_inicial']);
    } catch (_) {}

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

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Column(
          children: [
            const Icon(Icons.receipt_long, color: Colors.amber, size: 40),
            const SizedBox(height: 8),
            Text(
              "Detalle del Viaje",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: baseFontSize + 4,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Divider(thickness: 1),
              _filaDetalle("📍 Origen:", origen, baseFontSize),
              _filaDetalle("🏁 Destino:", destino, baseFontSize),
              const Divider(thickness: 1),
              if (horaInicio != null)
                _filaDetalle(
                    "🕓 Inicio:", formatoFechaHora(horaInicio), baseFontSize),
              if (horaFin != null)
                _filaDetalle(
                    "🏁 Fin:", formatoFechaHora(horaFin), baseFontSize),
              _filaDetalle("⏱ Duración:", "$duracion min", baseFontSize),
              const Divider(thickness: 1),
              _filaDetalle("Calificación:", calificacionTexto, baseFontSize),
            ],
          ),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop(); // ✅ usar dialogContext
            },
            child: Text(
              "Cerrar",
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: baseFontSize,
                color: Theme.of(dialogContext).primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

// ✅ Función auxiliar para estructurar las filas
  Widget _filaDetalle(String titulo, String valor, double fontSize) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Text(
              titulo,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: fontSize,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 4,
            child: Text(
              valor,
              style: TextStyle(fontSize: fontSize, color: Colors.black54),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String clienteId = FirebaseAuth.instance.currentUser?.uid ?? "";

    return Scaffold(
      appBar: AppBar(
        title: const Text("Historial de Viajes"),
        backgroundColor: Colors.amber,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('historial viaje')
            .where('clienteId', isEqualTo: clienteId)
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
                  leading: const Icon(Icons.receipt_long, color: Colors.amber),
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

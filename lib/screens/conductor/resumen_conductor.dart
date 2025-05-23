import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:taxi_app/screens/conductor/mapa_conductor.dart';

class ResumenConductor extends StatelessWidget {
  final String solicitudId;

  const ResumenConductor({Key? key, required this.solicitudId})
      : super(key: key);

  // Formateo simple para mostrar hora Bogotá
  String formatoHoraBogota(Timestamp timestamp) {
    final fecha = timestamp.toDate().toUtc().subtract(const Duration(hours: 5));
    final dia = fecha.day.toString().padLeft(2, '0');
    final mes = fecha.month.toString().padLeft(2, '0');
    final anio = fecha.year;
    final hora = fecha.hour.toString().padLeft(2, '0');
    final minuto = fecha.minute.toString().padLeft(2, '0');
    return "$dia/$mes/$anio $hora:$minuto";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('solicitud')
            .doc(solicitudId)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError ||
              !snapshot.hasData ||
              !snapshot.data!.exists) {
            return const Center(child: Text("Error al cargar los datos"));
          }

          // Cast to Map<String, dynamic>
          var solicitudData = snapshot.data!.data() as Map<String, dynamic>;
          var ubicacionInicial = solicitudData['ubicacion_inicial'];
          var direccionSeleccionada = solicitudData['direccion_seleccionada'];
          var clienteId = solicitudData['clienteId'];
          var horaInicio = solicitudData['hora_aceptacion'] as Timestamp?;
          var horaFin = solicitudData['fecha_terminacion'] as Timestamp?;
          var conductorId = solicitudData['conductorId'];

          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('cliente')
                .doc(clienteId)
                .get(),
            builder: (context, clienteSnapshot) {
              if (clienteSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (clienteSnapshot.hasError ||
                  !clienteSnapshot.hasData ||
                  !clienteSnapshot.data!.exists) {
                return const Center(
                    child: Text("Error al cargar los datos del cliente"));
              }

              var clienteData = clienteSnapshot.data!;
              var nombreCliente = clienteData['nombre'];

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

                  if (placemarksSnapshot.hasError ||
                      !placemarksSnapshot.hasData ||
                      placemarksSnapshot.data!.isEmpty) {
                    return const Center(child: Text("Dirección no disponible"));
                  }

                  var placemark = placemarksSnapshot.data!.first;
                  String direccionRecogida =
                      "${placemark.street}, ${placemark.locality}, ${placemark.country}";

                  return SafeArea(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(height: 24),
                          Center(
                            child: Image.asset(
                              'assets/img/taxi.png',
                              height: 200,
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.person,
                                    size: 40, color: Color(0xFFFFD600)),
                                const SizedBox(width: 8),
                                Text(
                                  nombreCliente.toString().toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "📍 Dirección de Recogida:",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                                Text(
                                  direccionRecogida,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  "🏁 Dirección Seleccionada:",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                                Text(
                                  direccionSeleccionada ?? "No disponible",
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                if (horaInicio != null) ...[
                                  const Text(
                                    "🕓 Hora de Inicio:",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  Text(
                                    formatoHoraBogota(horaInicio),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ],
                                if (horaFin != null) ...[
                                  const Text(
                                    "🕓 Hora de Finalización:",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  Text(
                                    formatoHoraBogota(horaFin),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 30),
                          SizedBox(
                            width: MediaQuery.of(context).size.width * 0.8,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: () async {
                                Navigator.of(context).pushAndRemoveUntil(
                                  MaterialPageRoute(
                                      builder: (_) => const MapaConductor()),
                                  (route) => false,
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFFD600),
                                foregroundColor: Colors.black,
                                textStyle: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text("Volver a Inicio"),
                            ),
                          ),
                          const SizedBox(height: 30),
                        ],
                      ),
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

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:taxi_app/screens/conductor/mapa_conductor.dart';

class ResumenConductor extends StatelessWidget {
  final String solicitudId;

  const ResumenConductor({Key? key, required this.solicitudId})
      : super(key: key);

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
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final scale = screenWidth / 375;

    final double iconSize = 40 * scale;
    final double padding = 24 * scale;
    final double imageHeight = 200 * scale;
    final double buttonHeight = 50 * scale;
    final double fontSizeButton = 18 * scale;
    final TextStyle titleStyle = TextStyle(
      fontSize: 18 * scale,
      fontWeight: FontWeight.w600,
      color: Colors.black87,
    );
    final TextStyle contentStyle = TextStyle(
      fontSize: 16 * scale,
      fontWeight: FontWeight.bold,
    );

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

          final solicitudData = snapshot.data!.data() as Map<String, dynamic>;
          final ubicacionInicial = solicitudData['ubicacion_inicial'];
          final direccionSeleccionada = solicitudData['direccion_seleccionada'];
          final clienteId = solicitudData['clienteId'];
          final horaInicio = solicitudData['hora_aceptacion'] as Timestamp?;
          final horaFin = solicitudData['fecha_terminacion'] as Timestamp?;
          final valorServicio = solicitudData['valor_servicio'] ?? 0;

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

              final clienteData = clienteSnapshot.data!;
              final nombreCliente = clienteData['nombre'];

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

                  final placemark = placemarksSnapshot.data!.first;
                  final direccionRecogida =
                      "${placemark.street}, ${placemark.locality}, ${placemark.country}";

                  return SafeArea(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.symmetric(horizontal: padding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          SizedBox(height: padding),
                          Image.asset(
                            'assets/img/taxi.png',
                            height: imageHeight,
                            fit: BoxFit.contain,
                          ),
                          SizedBox(height: padding * 0.8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Row(
                              children: [
                                Icon(Icons.person,
                                    size: iconSize,
                                    color: const Color(0xFFFFD600)),
                                SizedBox(width: 8 * scale),
                                Expanded(
                                  child: Text(
                                    nombreCliente.toString().toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 22 * scale,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: padding * 0.7),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("📍 Dirección de Recogida:",
                                    style: titleStyle),
                                Text(direccionRecogida, style: contentStyle),
                                SizedBox(height: 16 * scale),
                                Text("🏁 Dirección Seleccionada:",
                                    style: titleStyle),
                                Text(direccionSeleccionada ?? "No disponible",
                                    style: contentStyle),
                                SizedBox(height: 16 * scale),
                                if (horaInicio != null) ...[
                                  Text("🕓 Hora de Inicio:", style: titleStyle),
                                  Text(formatoHoraBogota(horaInicio),
                                      style: contentStyle),
                                  SizedBox(height: 16 * scale),
                                ],
                                if (horaFin != null) ...[
                                  Text("🕓 Hora de Finalización:",
                                      style: titleStyle),
                                  Text(formatoHoraBogota(horaFin),
                                      style: contentStyle),
                                  SizedBox(height: 16 * scale),
                                ],
                                Text("💲 Valor del Servicio:",
                                    style: titleStyle),
                                Text("\$${valorServicio.toString()}",
                                    style: contentStyle),
                              ],
                            ),
                          ),
                          SizedBox(height: 30 * scale),
                          SizedBox(
                            width: screenWidth * 0.8,
                            height: buttonHeight,
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.of(context).pushAndRemoveUntil(
                                  MaterialPageRoute(
                                      builder: (_) => const MapaConductor()),
                                  (route) => false,
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFFD600),
                                foregroundColor: Colors.black,
                                textStyle: TextStyle(
                                  fontSize: fontSizeButton,
                                  fontWeight: FontWeight.bold,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text("Volver a Inicio"),
                            ),
                          ),
                          SizedBox(height: 30 * scale),
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

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:taxi_app/components/boton.dart';

class SolicitudPendienteWidget extends StatelessWidget {
  final Stream<DocumentSnapshot> stream;
  final double scale;
  final Future<String> Function(String clienteId) obtenerNombreCliente;
  final Future<String> Function(GeoPoint origen) obtenerDireccion;
  final VoidCallback onAceptar;
  final VoidCallback onRechazar;

  const SolicitudPendienteWidget({
    Key? key,
    required this.stream,
    required this.scale,
    required this.obtenerNombreCliente,
    required this.obtenerDireccion,
    required this.onAceptar,
    required this.onRechazar,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const SizedBox.shrink();
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        if (data['estado'] != 'pendiente') return const SizedBox.shrink();

        final GeoPoint origen = data['ubicacion_inicial'];
        final String destino = data['direccion_seleccionada'] ?? "";
        final String clienteId = data['clienteId'];

        return FutureBuilder<List<String>>(
          future: Future.wait([
            obtenerNombreCliente(clienteId),
            obtenerDireccion(origen),
          ]),
          builder: (_, snapshot) {
            if (!snapshot.hasData) return const SizedBox.shrink();
            final nombre = snapshot.data![0];
            final dir = snapshot.data![1];

            return Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Card(
                elevation: 5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: EdgeInsets.all(16 * scale),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("🚖 Solicitud Entrante",
                          style: TextStyle(
                              fontSize: 18 * scale,
                              fontWeight: FontWeight.bold)),
                      SizedBox(height: 8 * scale),
                      Text("🛤 Origen: $dir",
                          style: TextStyle(fontSize: 14 * scale)),
                      SizedBox(height: 4 * scale),
                      Text("📍 Destino: $destino",
                          style: TextStyle(fontSize: 14 * scale)),
                      SizedBox(height: 16 * scale),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          CustomButton(
                            text: 'Rechazar',
                            onPressed: onRechazar,
                            width: 145 * scale,
                            height: 50 * scale,
                            fontSize: 16 * scale,
                            icon: const Icon(Icons.cancel),
                          ),
                          CustomButton(
                            text: 'Aceptar',
                            onPressed: onAceptar,
                            width: 145 * scale,
                            height: 50 * scale,
                            fontSize: 16 * scale,
                            icon: const Icon(Icons.check),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

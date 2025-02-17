import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class ClienteRecogida extends StatelessWidget {
  final String solicitudId;
  final String conductorId;
  final LatLng ubicacionInicial;
  final LatLng ubicacionDestino;

  const ClienteRecogida({
    Key? key,
    required this.solicitudId,
    required this.conductorId,
    required this.ubicacionInicial,
    required this.ubicacionDestino,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Recogida del Cliente")),
      body: Center(
        child: Text("Esperando al conductor..."),
      ),
    );
  }
}

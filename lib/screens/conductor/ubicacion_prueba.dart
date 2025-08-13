import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:taxi_app/controllers/conductor_controller.dart';


class UbicacionScreen extends StatefulWidget {
  const UbicacionScreen({Key? key}) : super(key: key);

  @override
  State<UbicacionScreen> createState() => _UbicacionScreenState();
}

class _UbicacionScreenState extends State<UbicacionScreen> {
  final controller = MapaConductorController();
  LatLng? _posicionActual;

  @override
  void initState() {
    super.initState();
    controller.iniciarRastreoUbicacion(
      (pos) => setState(() => _posicionActual = pos),
      collection: 'conductor',
      docId: FirebaseAuth.instance.currentUser!.uid,
    );
  }

  @override
  void dispose() {
    controller.detenerRastreo();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Guardando ubicación en tiempo real')),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _posicionActual ?? const LatLng(8.2595534, -73.353469),
              zoom: 15,
            ),
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            markers: {
              if (_posicionActual != null)
                Marker(
                  markerId: const MarkerId('ubicacion_actual'),
                  position: _posicionActual!,
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueBlue,
                  ),
                ),
            },
          ),
          Positioned(
            top: 20,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _posicionActual != null
                    ? '📍 ${_posicionActual!.latitude.toStringAsFixed(5)}, ${_posicionActual!.longitude.toStringAsFixed(5)}'
                    : 'Esperando ubicación...',
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class SolicitudListenerPage extends StatefulWidget {
  final String solicitudId;

  const SolicitudListenerPage({Key? key, required this.solicitudId})
      : super(key: key);

  @override
  _SolicitudListenerPageState createState() => _SolicitudListenerPageState();
}

class _SolicitudListenerPageState extends State<SolicitudListenerPage> {
  late Stream<DocumentSnapshot<Map<String, dynamic>>> _solicitudStream;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  bool _mostrarInformacionUbicacion = false;
  bool _mostrarBotonTaxi = true;

  @override
  void initState() {
    super.initState();
    _solicitudStream = FirebaseFirestore.instance
        .collection('solicitud')
        .doc(widget.solicitudId)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Escuchando Solicitud")),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _solicitudStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: CircularProgressIndicator());
          }

          var doc = snapshot.data!;
          if (!doc.exists) {
            return const Center(child: Text("Solicitud no encontrada"));
          }

          String estado = doc['estado'] ?? '';

          if (estado == 'cancelada') {
            _eliminarSolicitud(widget.solicitudId);
          } else if (estado == 'aceptada') {
            _actualizarEstadoSolicitud(doc);
          }

          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("Estado de la solicitud: $estado"),
                const SizedBox(height: 20),
                if (_mostrarBotonTaxi)
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Volver"),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// ✅ Si la solicitud es "cancelada", eliminarla de Firestore y actualizar la UI
  Future<void> _eliminarSolicitud(String solicitudId) async {
    await FirebaseFirestore.instance
        .collection('solicitud')
        .doc(solicitudId)
        .delete();

    if (mounted) {
      setState(() {
        _mostrarInformacionUbicacion = false;
        _mostrarBotonTaxi = true;
        _markers
            .removeWhere((m) => m.markerId.value == "ubicacion_seleccionada");
        _polylines.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Solicitud cancelada y eliminada de la base de datos.')),
      );
    }
  }

  /// ✅ Si la solicitud es "aceptada", actualiza el estado sin navegación
  void _actualizarEstadoSolicitud(DocumentSnapshot<Map<String, dynamic>> doc) {
    String conductorId = doc['conductorId'] ?? '';
    GeoPoint ubicacionInicial = doc['ubicacion_inicial'];
    GeoPoint ubicacionDestino = doc['ubicacion_seleccionada'];

    if (mounted) {
      setState(() {
        _mostrarInformacionUbicacion = true;
        _markers.add(Marker(
          markerId: const MarkerId("ubicacion_seleccionada"),
          position:
              LatLng(ubicacionDestino.latitude, ubicacionDestino.longitude),
          infoWindow: InfoWindow(title: "Destino seleccionado"),
        ));

        _polylines.clear();
        _polylines.add(Polyline(
          polylineId: const PolylineId('ruta'),
          points: [
            LatLng(ubicacionInicial.latitude, ubicacionInicial.longitude),
            LatLng(ubicacionDestino.latitude, ubicacionDestino.longitude)
          ],
          color: Colors.blue,
          width: 4,
        ));
      });
    }
  }
}

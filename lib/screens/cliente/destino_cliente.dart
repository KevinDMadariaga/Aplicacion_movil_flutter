import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class DestinoCliente extends StatefulWidget {
  final LatLng ubicacionInicial;
  final LatLng ubicacionDestino;

  const DestinoCliente({
    Key? key,
    required this.ubicacionInicial,
    required this.ubicacionDestino,
  }) : super(key: key);

  @override
  _DestinoClienteState createState() => _DestinoClienteState();
}

class _DestinoClienteState extends State<DestinoCliente> {
  late GoogleMapController _mapController;
  Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _cargarMarcadores();
  }

  void _cargarMarcadores() {
    setState(() {
      _markers.add(Marker(
        markerId: const MarkerId("ubicacion_inicial"),
        position: widget.ubicacionInicial,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: const InfoWindow(title: "📍 Punto de Recogida"),
      ));

      _markers.add(Marker(
        markerId: const MarkerId("ubicacion_destino"),
        position: widget.ubicacionDestino,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: const InfoWindow(title: "🏁 Destino"),
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Destino del Cliente")),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: widget.ubicacionInicial,
          zoom: 14,
        ),
        markers: _markers,
        onMapCreated: (controller) {
          _mapController = controller;
        },
      ),
    );
  }
}

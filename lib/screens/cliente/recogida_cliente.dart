import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';

class ClienteRecogida extends StatefulWidget {
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
  _ClienteRecogidaState createState() => _ClienteRecogidaState();
}

class _ClienteRecogidaState extends State<ClienteRecogida> {
  late GoogleMapController _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  LatLng? _ubicacionConductor;
  String _nombreConductor = "Desconocido";
  String _tiempoEstimado = "Calculando...";
  StreamSubscription<DocumentSnapshot>? _conductorSubscription;

  @override
  void initState() {
    super.initState();
    _obtenerDatosConductor();
    _escucharUbicacionConductor();
  }

  @override
  void dispose() {
    _conductorSubscription?.cancel();
    super.dispose();
  }

  Future<void> _obtenerDatosConductor() async {
    try {
      DocumentSnapshot conductorSnapshot = await FirebaseFirestore.instance
          .collection('conductor')
          .doc(widget.conductorId)
          .get();

      if (conductorSnapshot.exists) {
        setState(() {
          _nombreConductor =
              conductorSnapshot['nombre'] ?? "Conductor desconocido";
        });
      }
    } catch (e) {
      debugPrint("Error al obtener datos del conductor: $e");
    }
  }

  void _escucharUbicacionConductor() {
    _conductorSubscription = FirebaseFirestore.instance
        .collection('conductor')
        .doc(widget.conductorId)
        .snapshots()
        .listen((doc) {
      if (doc.exists && doc.data()!.containsKey('ubicacion')) {
        GeoPoint posicion = doc['ubicacion'];

        setState(() {
          _ubicacionConductor = LatLng(posicion.latitude, posicion.longitude);
          _actualizarMapa();
          _actualizarTrazabilidad();
        });

        _calcularTiempoEstimado();
      } else {
        debugPrint("No se encontró la ubicación del conductor en Firestore.");
      }
    });
  }

  Future<void> _calcularTiempoEstimado() async {
    if (_ubicacionConductor != null) {
      double distancia = Geolocator.distanceBetween(
        _ubicacionConductor!.latitude,
        _ubicacionConductor!.longitude,
        widget.ubicacionInicial.latitude,
        widget.ubicacionInicial.longitude,
      );

      int tiempoEnMinutos = (distancia / 250).round();
      setState(() {
        _tiempoEstimado = "$tiempoEnMinutos min";
      });
    }
  }

  void _actualizarTrazabilidad() {
    if (_ubicacionConductor == null) return;

    setState(() {
      _polylines.clear();
      _polylines.add(Polyline(
        polylineId: const PolylineId("trazabilidad"),
        color: Colors.blueAccent,
        width: 5,
        points: [
          _ubicacionConductor!,
          widget.ubicacionInicial,
        ],
      ));
    });

    _mapController.animateCamera(
      CameraUpdate.newLatLng(_ubicacionConductor!),
    );
  }

  void _actualizarMapa() {
    _markers.clear();

    _markers.add(Marker(
      markerId: const MarkerId("cliente"),
      position: widget.ubicacionInicial,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      infoWindow: const InfoWindow(title: "📍 Cliente"),
    ));

    if (_ubicacionConductor != null) {
      _markers.add(Marker(
        markerId: const MarkerId("conductor"),
        position: _ubicacionConductor!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        infoWindow: InfoWindow(title: "🚖 $_nombreConductor"),
      ));
    }

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: const Text("Seguimiento del Conductor")),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text(
                "CONDUCTOR EN RUTA",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            Container(
              height: 250, // Tamaño reducido del mapa
              margin: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  )
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: widget.ubicacionInicial,
                    zoom: 14,
                  ),
                  markers: _markers,
                  polylines: _polylines,
                  onMapCreated: (controller) => _mapController = controller,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "🚖 $_nombreConductor",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              "⏳ Tiempo estimado: $_tiempoEstimado",
              style: TextStyle(fontSize: 18),
            ),
          ],
        ));
  }
}

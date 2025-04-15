import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';

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
  String _nombreConductor = "DESCONOCIDO";
  String _tiempoEstimado = "Calculando...";
  String _direccionConductor = "Obteniendo dirección...";
  double _progreso = 0.0;
  bool _recogido = false;

  @override
  void initState() {
    super.initState();
    _obtenerDatosConductor();
    _escucharUbicacionConductor();
  }

  @override
  void dispose() {
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
              conductorSnapshot['nombre'].toString().toUpperCase();
        });
      }
    } catch (e) {
      debugPrint("Error al obtener datos del conductor: $e");
    }
  }

  void _escucharUbicacionConductor() {
    FirebaseFirestore.instance
        .collection('conductor')
        .doc(widget.conductorId)
        .snapshots()
        .listen((doc) async {
      if (doc.exists && doc.data()!.containsKey('ubicacion')) {
        GeoPoint posicion = doc['ubicacion'];
        setState(() {
          _ubicacionConductor = LatLng(posicion.latitude, posicion.longitude);
          _actualizarMapa();
          _actualizarTrazabilidad();
        });
        await _obtenerDireccionConductor();
      } else {
        debugPrint("No se encontró la ubicación del conductor en Firestore.");
      }
    });
  }

  Future<void> _obtenerDireccionConductor() async {
    if (_ubicacionConductor != null) {
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          _ubicacionConductor!.latitude,
          _ubicacionConductor!.longitude,
        );

        if (placemarks.isNotEmpty) {
          Placemark lugar = placemarks.first;
          setState(() {
            _direccionConductor =
                "${lugar.street}, ${lugar.subLocality}, ${lugar.locality}";
          });
        } else {
          setState(() {
            _direccionConductor = "Dirección no disponible";
          });
        }
      } catch (e) {
        debugPrint("Error al obtener la dirección: $e");
        setState(() {
          _direccionConductor = "Error al obtener la dirección";
        });
      }
    }
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

  void _actualizarTrazabilidad() {
    if (_ubicacionConductor == null) return;

    setState(() {
      _polylines.clear();
      _polylines.add(Polyline(
        polylineId: const PolylineId("trazabilidad"),
        color: Colors.green,
        width: 5,
        points: [
          _ubicacionConductor!,
          widget.ubicacionInicial,
        ],
      ));
    });
  }

  void _ajustarCamara() {
    if (_ubicacionConductor == null) return;

    final latitudes = [
      _ubicacionConductor!.latitude,
      widget.ubicacionInicial.latitude
    ];
    final longitudes = [
      _ubicacionConductor!.longitude,
      widget.ubicacionInicial.longitude
    ];

    final bounds = LatLngBounds(
      southwest: LatLng(
        latitudes.reduce((a, b) => a < b ? a : b),
        longitudes.reduce((a, b) => a < b ? a : b),
      ),
      northeast: LatLng(
        latitudes.reduce((a, b) => a > b ? a : b),
        longitudes.reduce((a, b) => a > b ? a : b),
      ),
    );

    _mapController.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Seguimiento del Conductor")),
      body: Column(
        children: [
          Container(
            height: MediaQuery.of(context).size.height * 0.4,
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
                onMapCreated: (controller) {
                  _mapController = controller;
                  _ajustarCamara();
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 35,
                  backgroundColor: Colors.grey[300],
                  backgroundImage: AssetImage(
                      'assets/images/default_avatar.png'), // Puedes cambiarlo por NetworkImage si usas URL de Firestore
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "🚖 $_nombreConductor",
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "📍 $_direccionConductor",
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "⏳ Tiempo estimado: $_tiempoEstimado",
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          LinearPercentIndicator(
            animation: true,
            lineHeight: 20.0,
            percent: _progreso,
            barRadius: const Radius.circular(10),
            progressColor: Colors.green,
            backgroundColor: Colors.grey[300]!,
          ),
        ],
      ),
    );
  }
}

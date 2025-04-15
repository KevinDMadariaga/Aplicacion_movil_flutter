import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:taxi_app/components/boton.dart';
import 'package:taxi_app/screens/conductor/destino_conductor.dart';

class ConductorRecogida extends StatefulWidget {
  final String clienteId;
  final String solicitudId;
  final GeoPoint ubicacionInicial;
  final GeoPoint ubicacionDestino;

  const ConductorRecogida({
    Key? key,
    required this.clienteId,
    required this.solicitudId,
    required this.ubicacionInicial,
    required this.ubicacionDestino,
  }) : super(key: key);

  @override
  _ConductorRecogidaState createState() => _ConductorRecogidaState();
}

class _ConductorRecogidaState extends State<ConductorRecogida> {
  StreamSubscription<Position>? _positionStreamSubscription;
  Position? _currentPosition;
  GoogleMapController? _mapController;
  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};
  String _tiempoEstimado = "Calculando...";
  String _nombreCliente = "CARGANDO...";
  String _direccionCliente = "Obteniendo dirección...";
  bool _notificando = false; // Nueva bandera de carga

  @override
  void initState() {
    super.initState();
    _obtenerNombreCliente();
    _obtenerDireccionCliente();
    _iniciarActualizacionUbicacion();
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    super.dispose();
  }

  void _obtenerNombreCliente() async {
    try {
      DocumentSnapshot clienteDoc = await FirebaseFirestore.instance
          .collection('cliente')
          .doc(widget.clienteId)
          .get();

      if (clienteDoc.exists && mounted) {
        setState(() {
          _nombreCliente = clienteDoc['nombre'].toString().toUpperCase();
        });
      }
    } catch (e) {
      debugPrint("Error al obtener nombre del cliente: $e");
    }
  }

  Future<void> _obtenerDireccionCliente() async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        widget.ubicacionInicial.latitude,
        widget.ubicacionInicial.longitude,
      );

      if (placemarks.isNotEmpty && mounted) {
        Placemark lugar = placemarks.first;
        setState(() {
          _direccionCliente =
              "${lugar.street}, ${lugar.subLocality}, ${lugar.locality}";
        });
      }
    } catch (e) {
      debugPrint("Error al obtener la dirección: $e");
    }
  }

  void _iniciarActualizacionUbicacion() async {
    LocationPermission permission = await Geolocator.requestPermission();
    LocationSettings settings = const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );

    _positionStreamSubscription =
        Geolocator.getPositionStream(locationSettings: settings).listen(
      (Position posicion) async {
        if (!mounted) return;

        setState(() {
          _currentPosition = posicion;
          _actualizarMapa();
        });

        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await FirebaseFirestore.instance
              .collection('conductor')
              .doc(user.uid)
              .set({
            'ubicacion': GeoPoint(posicion.latitude, posicion.longitude),
            'ultima_actualizacion': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }

        double distancia = Geolocator.distanceBetween(
          posicion.latitude,
          posicion.longitude,
          widget.ubicacionInicial.latitude,
          widget.ubicacionInicial.longitude,
        );

        setState(() {
          _tiempoEstimado = "${(distancia / 250).round()} min";
          _polylines = {
            Polyline(
              polylineId: const PolylineId("ruta"),
              points: [
                LatLng(posicion.latitude, posicion.longitude),
                LatLng(widget.ubicacionInicial.latitude,
                    widget.ubicacionInicial.longitude),
              ],
              color: Colors.green,
              width: 5,
            ),
          };
        });
      },
    );
  }

  void _actualizarMapa() {
    _markers.clear();

    _markers.add(
      Marker(
        markerId: const MarkerId("cliente"),
        position: LatLng(
          widget.ubicacionInicial.latitude,
          widget.ubicacionInicial.longitude,
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: const InfoWindow(title: "📍 Cliente"),
      ),
    );

    if (_currentPosition != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId("conductor"),
          position: LatLng(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(title: "🚖 Conductor"),
        ),
      );
    }

    setState(() {});
  }

  Future<void> _notificarLlegada() async {
    if (_notificando || _currentPosition == null) return;

    setState(() {
      _notificando = true;
    });

    try {
      await FirebaseFirestore.instance
          .collection('solicitud')
          .doc(widget.solicitudId)
          .update({
        'llegada_conductor': 'llego',
        'timestamp_llegada': FieldValue.serverTimestamp(),
        'estado': 'en destino',
      });

      await Future.delayed(const Duration(seconds: 2));

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => DestinoConductor(
            ubicacionConductor: LatLng(
              _currentPosition!.latitude,
              _currentPosition!.longitude,
            ),
            ubicacionDestino: LatLng(
              widget.ubicacionDestino.latitude,
              widget.ubicacionDestino.longitude,
            ),
            solicitudId: widget.solicitudId,
          ),
        ),
      );
    } catch (e) {
      debugPrint("Error al notificar llegada: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error al notificar la llegada: $e")),
        );
        setState(() {
          _notificando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("SEGUIMIENTO DEL CLIENTE")),
      body: Column(
        children: [
          const SizedBox(height: 10),
          const Text(
            "RECOGER AL CLIENTE",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Container(
            height: 350,
            margin: const EdgeInsets.symmetric(horizontal: 15),
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(widget.ubicacionInicial.latitude,
                    widget.ubicacionInicial.longitude),
                zoom: 15,
              ),
              onMapCreated: (controller) {
                _mapController = controller;
              },
              polylines: _polylines,
              markers: _markers,
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 35,
                  backgroundColor: Colors.grey[300],
                  backgroundImage:
                      const AssetImage('assets/images/default_avatar.png'),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "$_nombreCliente",
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "📍 $_direccionCliente",
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "⏳ Tiempo estimado: $_tiempoEstimado",
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _notificando
              ? const CircularProgressIndicator()
              : CustomButton(
                  text: 'Ya llegué',
                  onPressed: _notificarLlegada,
                  width: 130,
                  height: 50,
                  fontSize: 16,
                ),
        ],
      ),
    );
  }
}

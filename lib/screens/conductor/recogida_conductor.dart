import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';

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

  @override
  void initState() {
    super.initState();
    _obtenerNombreCliente();
    _obtenerDireccionCliente();
    _iniciarActualizacionUbicacion();
  }

  void _obtenerNombreCliente() async {
    try {
      DocumentSnapshot clienteDoc = await FirebaseFirestore.instance
          .collection('cliente')
          .doc(widget.clienteId)
          .get();

      if (clienteDoc.exists) {
        setState(() {
          _nombreCliente = clienteDoc['nombre'].toString().toUpperCase();
        });
      } else {
        setState(() {
          _nombreCliente = "NO ENCONTRADO";
        });
      }
    } catch (e) {
      debugPrint("Error al obtener nombre del cliente: $e");
      setState(() {
        _nombreCliente = "ERROR AL CARGAR";
      });
    }
  }

  Future<void> _obtenerDireccionCliente() async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        widget.ubicacionInicial.latitude,
        widget.ubicacionInicial.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark lugar = placemarks.first;
        setState(() {
          _direccionCliente =
              "${lugar.street}, ${lugar.subLocality}, ${lugar.locality}";
        });
      } else {
        setState(() {
          _direccionCliente = "Dirección no disponible";
        });
      }
    } catch (e) {
      debugPrint("Error al obtener la dirección: $e");
      setState(() {
        _direccionCliente = "Error al obtener la dirección";
      });
    }
  }

  void _iniciarActualizacionUbicacion() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Los servicios de ubicación están deshabilitados.')),
      );
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permisos de ubicación denegados.')),
        );
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Permisos de ubicación denegados permanentemente.')),
      );
      return;
    }

    LocationSettings settings = const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );

    _positionStreamSubscription =
        Geolocator.getPositionStream(locationSettings: settings).listen(
      (Position posicion) async {
        setState(() {
          _currentPosition = posicion;
          _actualizarMapa();
        });

        final User? user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await FirebaseFirestore.instance
              .collection('conductor')
              .doc(user.uid)
              .set(
            {
              'ubicacion': GeoPoint(posicion.latitude, posicion.longitude),
              'ultima_actualizacion': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
        }

        _ajustarCamara();

        double distanceToPickup = Geolocator.distanceBetween(
          posicion.latitude,
          posicion.longitude,
          widget.ubicacionInicial.latitude,
          widget.ubicacionInicial.longitude,
        );
        int tiempoEnMinutos = (distanceToPickup / 250).round();
        setState(() {
          _tiempoEstimado = "$tiempoEnMinutos min";
        });

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
      },
    );
  }

void _notificarLlegada() async {
    try {
      if (widget.solicitudId.isEmpty) {
        debugPrint("Error: solicitudId está vacío.");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error: ID de solicitud no válido.")),
        );
        return;
      }
      
      await FirebaseFirestore.instance
          .collection('solicitud')
          .doc(widget.solicitudId)
          .update(
        {
          'llegada_conductor': 'llego',
          'timestamp_llegada': FieldValue.serverTimestamp(),
        },
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Has notificado tu llegada al cliente.")),
      );
    } catch (e) {
      debugPrint("Error al notificar llegada: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error al notificar la llegada: $e")),
      );
    }
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

      _ajustarCamara();
    }

    setState(() {});
  }

  void _ajustarCamara() {
    if (_mapController != null && _currentPosition != null) {
      LatLngBounds bounds = LatLngBounds(
        southwest: LatLng(
          _currentPosition!.latitude < widget.ubicacionInicial.latitude
              ? _currentPosition!.latitude
              : widget.ubicacionInicial.latitude,
          _currentPosition!.longitude < widget.ubicacionInicial.longitude
              ? _currentPosition!.longitude
              : widget.ubicacionInicial.longitude,
        ),
        northeast: LatLng(
          _currentPosition!.latitude > widget.ubicacionInicial.latitude
              ? _currentPosition!.latitude
              : widget.ubicacionInicial.latitude,
          _currentPosition!.longitude > widget.ubicacionInicial.longitude
              ? _currentPosition!.longitude
              : widget.ubicacionInicial.longitude,
        ),
      );

      _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
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
                _ajustarCamara();
              },
              polylines: _polylines,
              markers: _markers,
            ),
          ),
          const SizedBox(height: 20),
          Text("Cliente: $_nombreCliente",
              style: const TextStyle(fontSize: 18)),
          Text("📍 $_direccionCliente", style: const TextStyle(fontSize: 16)),
          Text("⏳ Tiempo estimado: $_tiempoEstimado",
              style: const TextStyle(fontSize: 16, color: Colors.green)),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _notificarLlegada,
            child: const Text("Notificar llegada"),
          ),
        ],
      ),
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class ConductorRecogida extends StatefulWidget {
  final String clienteId;
  final GeoPoint ubicacionInicial; // Ubicación del cliente (punto de recogida)
  final GeoPoint
      ubicacionDestino; // Ubicación destino (se conserva, pero no se muestra en el mapa)

  const ConductorRecogida({
    Key? key,
    required this.clienteId,
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
  String _tiempoEstimado = "Calculando...";
  String _nombreCliente = "Cargando...";

  @override
  void initState() {
    super.initState();
    _obtenerNombreCliente();
    _iniciarActualizacionUbicacion();
  }

  // Inicia la actualización continua de la ubicación del conductor
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
        });

        // Actualiza la ubicación del conductor en Firestore
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
        } else {
          debugPrint("⚠️ Usuario no autenticado.");
        }

        // Actualiza la cámara del mapa a la nueva ubicación
        if (_mapController != null) {
          _mapController!.animateCamera(
            CameraUpdate.newLatLng(
                LatLng(posicion.latitude, posicion.longitude)),
          );
        }

        // Calcula la distancia al punto de recogida (ubicacionInicial)
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

        // Trazabilidad dinámica: línea entre la ubicación actual del conductor y la ubicación del cliente
        Set<Polyline> updatedPolylines = _polylines
            .where((p) => p.polylineId.value != "dynamicRoute")
            .toSet();
        updatedPolylines.add(
          Polyline(
            polylineId: const PolylineId("dynamicRoute"),
            points: [
              LatLng(posicion.latitude, posicion.longitude),
              LatLng(widget.ubicacionInicial.latitude,
                  widget.ubicacionInicial.longitude),
            ],
            color: Colors.green,
            width: 3,
          ),
        );
        setState(() {
          _polylines = updatedPolylines;
        });

        // Si se llega al punto de recogida (dentro de un radio de 10 metros), se detiene la actualización.
        if (distanceToPickup <= 10) {
          await _positionStreamSubscription?.cancel();
          _positionStreamSubscription = null;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Has llegado al punto de recogida del cliente.')),
          );
        }
      },
      onError: (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al actualizar ubicación: $error')),
        );
      },
    );
  }

  void _obtenerNombreCliente() async {
    try {
      DocumentSnapshot clienteDoc = await FirebaseFirestore.instance
          .collection('cliente')
          .doc(widget.clienteId)
          .get();

      if (clienteDoc.exists) {
        setState(() {
          _nombreCliente = clienteDoc['nombre'] ?? "Desconocido";
        });
      } else {
        setState(() {
          _nombreCliente = "No encontrado";
        });
      }
    } catch (e) {
      debugPrint("Error al obtener nombre del cliente: $e");
      setState(() {
        _nombreCliente = "Error al cargar";
      });
    }
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Se centra el mapa en la ubicación actual si está disponible, o en la ubicación del cliente
    LatLng initialCameraPosition = LatLng(
      widget.ubicacionInicial.latitude,
      widget.ubicacionInicial.longitude,
    );
    if (_currentPosition != null) {
      initialCameraPosition = LatLng(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
      );
    }

    String ubicacionActual = _currentPosition != null
        ? "Lat ${_currentPosition!.latitude.toStringAsFixed(5)}, Lng ${_currentPosition!.longitude.toStringAsFixed(5)}"
        : "Obteniendo ubicación...";

    return Scaffold(
      appBar: AppBar(title: const Text("Recogida del Cliente")),
      body: Column(
        children: [
          Expanded(
            flex: 2,
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: initialCameraPosition,
                zoom: 15,
              ),
              onMapCreated: (GoogleMapController controller) {
                _mapController = controller;
              },
              polylines: _polylines,
              // Se muestran únicamente los marcadores para el cliente y para el conductor
              markers: {
                Marker(
                  markerId: const MarkerId("pickup"),
                  position: LatLng(
                    widget.ubicacionInicial.latitude,
                    widget.ubicacionInicial.longitude,
                  ),
                  infoWindow: const InfoWindow(title: "Cliente"),
                ),
                if (_currentPosition != null)
                  Marker(
                    markerId: const MarkerId("current"),
                    position: LatLng(
                      _currentPosition!.latitude,
                      _currentPosition!.longitude,
                    ),
                    infoWindow: const InfoWindow(title: "Conductor"),
                  ),
              },
            ),
          ),
          Expanded(
            flex: 1,
            child: Center(
              child: Card(
                margin: const EdgeInsets.all(10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15.0),
                ),
                elevation: 5,
                child: Padding(
                  padding: const EdgeInsets.all(15.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Cliente: $_nombreCliente",
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "Ubicación Cliente:\nLat: ${widget.ubicacionInicial.latitude}, Lng: ${widget.ubicacionInicial.longitude}",
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "Tiempo estimado a recogida: $_tiempoEstimado",
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Center(
                        child: ElevatedButton(
                          onPressed: () async {
                            await _positionStreamSubscription?.cancel();
                            Navigator.pop(context);
                          },
                          child: const Text("Finalizar Recogida"),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ... [importaciones]
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import 'package:taxi_app/services/api_google.dart';
import 'package:taxi_app/utils/notificaciones.dart';

class ClienteRecogida extends StatefulWidget {
  final String solicitudId;
  const ClienteRecogida({Key? key, required this.solicitudId})
      : super(key: key);

  @override
  _ClienteRecogidaState createState() => _ClienteRecogidaState();
}

class _ClienteRecogidaState extends State<ClienteRecogida> {
  late GoogleMapController _mapController;
  LatLng? _ubicacionCliente;
  LatLng? _ubicacionConductor;
  String _nombreConductor = "DESCONOCIDO";
  String _direccionConductor = "Obteniendo dirección...";
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  double _progreso = 0.0;
  double _progresoActual = 0.0;
  double? _distanciaTotal;
  bool _notificado = false;
  String? _conductorId;
  Timer? _simulacionTimer;
  Marker? _markerConductor;

  @override
  void initState() {
    super.initState();
    _escucharSolicitud();
  }

  @override
  void dispose() {
    _simulacionTimer?.cancel();
    super.dispose();
  }

  void _escucharSolicitud() {
    FirebaseFirestore.instance
        .collection('solicitud')
        .doc(widget.solicitudId)
        .snapshots()
        .listen((doc) async {
      if (!doc.exists) return;
      final data = doc.data()!;
      final conductorId = data['conductorId'];
      final ubicacionCliente = data['ubicacion_inicial'];

      setState(() {
        _ubicacionCliente =
            LatLng(ubicacionCliente.latitude, ubicacionCliente.longitude);
        _conductorId = conductorId;
      });

      _obtenerDatosConductor(conductorId);
      _escucharUbicacionConductor(conductorId);
    });
  }

  Future<void> _obtenerDatosConductor(String conductorId) async {
    final doc = await FirebaseFirestore.instance
        .collection('conductor')
        .doc(conductorId)
        .get();
    if (doc.exists) {
      setState(() {
        _nombreConductor = doc['nombre'].toString().toUpperCase();
      });
    }
  }

  void _escucharUbicacionConductor(String conductorId) {
    FirebaseFirestore.instance
        .collection('conductor')
        .doc(conductorId)
        .snapshots()
        .listen((doc) async {
      if (doc.exists && doc.data()!.containsKey('ubicacion')) {
        GeoPoint geo = doc['ubicacion'];
        LatLng nuevaUbicacion = LatLng(geo.latitude, geo.longitude);
        _animarMovimientoConductor(nuevaUbicacion);
        _ubicacionConductor = nuevaUbicacion;
        await _obtenerDireccionConductor();
        await _actualizarMapa();
        _actualizarProgreso();
      }
    });
  }

  void _animarMovimientoConductor(LatLng nuevaPos) {
    if (_markerConductor == null) {
      _markerConductor = Marker(
        markerId: const MarkerId("conductor"),
        position: nuevaPos,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        infoWindow: InfoWindow(title: _nombreConductor),
      );
      _markers.add(_markerConductor!);
    } else {
      final marcadorAnterior = _markerConductor!;
      final LatLng inicio = marcadorAnterior.position;

      double t = 0.0;
      Timer.periodic(const Duration(milliseconds: 16), (timer) {
        t += 0.05;
        if (t >= 1.0) {
          timer.cancel();
          t = 1.0;
        }

        final lat = inicio.latitude + (nuevaPos.latitude - inicio.latitude) * t;
        final lng =
            inicio.longitude + (nuevaPos.longitude - inicio.longitude) * t;

        setState(() {
          _markerConductor = marcadorAnterior.copyWith(
            positionParam: LatLng(lat, lng),
          );
          _markers.removeWhere((m) => m.markerId.value == "conductor");
          _markers.add(_markerConductor!);
        });
      });
    }
  }

  Future<void> _obtenerDireccionConductor() async {
    if (_ubicacionConductor != null) {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        _ubicacionConductor!.latitude,
        _ubicacionConductor!.longitude,
      );
      if (placemarks.isNotEmpty) {
        final lugar = placemarks.first;
        setState(() {
          _direccionConductor = "${lugar.street}, ${lugar.locality}";
        });
      }
    }
  }

  Future<void> _actualizarMapa() async {
    if (_ubicacionCliente == null || _ubicacionConductor == null) return;

    final ruta =
        await obtenerRutaPorCalles(_ubicacionConductor!, _ubicacionCliente!);

    setState(() {
      _markers.add(
        Marker(
          markerId: const MarkerId("cliente"),
          position: _ubicacionCliente!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: const InfoWindow(title: "Cliente"),
        ),
      );
      _polylines = {
        Polyline(
          polylineId: const PolylineId("ruta_conductor_cliente"),
          color: Colors.blueAccent,
          width: 5,
          points: ruta,
        )
      };
    });

    final bounds = LatLngBounds(
      southwest: LatLng(
        [_ubicacionConductor!.latitude, _ubicacionCliente!.latitude]
            .reduce((a, b) => a < b ? a : b),
        [_ubicacionConductor!.longitude, _ubicacionCliente!.longitude]
            .reduce((a, b) => a < b ? a : b),
      ),
      northeast: LatLng(
        [_ubicacionConductor!.latitude, _ubicacionCliente!.latitude]
            .reduce((a, b) => a > b ? a : b),
        [_ubicacionConductor!.longitude, _ubicacionCliente!.longitude]
            .reduce((a, b) => a > b ? a : b),
      ),
    );

    _mapController.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
  }

  void _actualizarProgreso() {
    if (_ubicacionCliente == null || _ubicacionConductor == null) return;

    double distanciaActual = Geolocator.distanceBetween(
      _ubicacionConductor!.latitude,
      _ubicacionConductor!.longitude,
      _ubicacionCliente!.latitude,
      _ubicacionCliente!.longitude,
    );

    _distanciaTotal ??= distanciaActual;

    double nuevoProgreso = 1.0 - (distanciaActual / (_distanciaTotal! + 1));
    nuevoProgreso = nuevoProgreso.clamp(0.0, 1.0);

    if (!_notificado && nuevoProgreso >= 0.98) {
      _notificado = true;
      _mostrarNotificacionDeLlegada();
    }

    _progresoActual += (nuevoProgreso - _progresoActual) * 0.2;
    setState(() {
      _progreso = _progresoActual;
    });
  }

  void _mostrarNotificacionDeLlegada() {
    NotificacionLocal.mostrarNotificacion(
      id: 1,
      titulo: "Conductor cerca",
      cuerpo: "🚖 Tu conductor está a punto de llegar.",
    );
  }

  void _iniciarSimulacion() {
    _simulacionTimer?.cancel();
    _simulacionTimer =
        Timer.periodic(const Duration(milliseconds: 1000), (_) async {
      if (_conductorId == null ||
          _ubicacionConductor == null ||
          _ubicacionCliente == null) return;

      final deltaLat =
          (_ubicacionCliente!.latitude - _ubicacionConductor!.latitude) * 0.1;
      final deltaLng =
          (_ubicacionCliente!.longitude - _ubicacionConductor!.longitude) * 0.1;

      final nuevaUbicacion = LatLng(
        _ubicacionConductor!.latitude + deltaLat,
        _ubicacionConductor!.longitude + deltaLng,
      );

      await FirebaseFirestore.instance
          .collection('conductor')
          .doc(_conductorId)
          .update({
        'ubicacion':
            GeoPoint(nuevaUbicacion.latitude, nuevaUbicacion.longitude),
      });

      if ((deltaLat.abs() < 0.0001 && deltaLng.abs() < 0.0001) ||
          _progreso >= 0.98) {
        _simulacionTimer?.cancel();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Tu conductor en camino")),
      body: Column(
        children: [
          Expanded(
            flex: 5,
            child: GoogleMap(
              initialCameraPosition:
                  const CameraPosition(target: LatLng(0, 0), zoom: 14),
              markers: _markers,
              polylines: _polylines,
              onMapCreated: (controller) => _mapController = controller,
              myLocationEnabled: false,
              zoomControlsEnabled: false,
            ),
          ),
          Expanded(
            flex: 3,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [BoxShadow(blurRadius: 10, color: Colors.black12)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                          radius: 30, backgroundColor: Colors.grey),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("🚖 $_nombreConductor",
                                style: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text("📍 $_direccionConductor"),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text("🛣️ Progreso de llegada:",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  LinearPercentIndicator(
                    lineHeight: 14.0,
                    percent: _progreso,
                    barRadius: const Radius.circular(10),
                    progressColor: Colors.green,
                    backgroundColor: Colors.grey[300]!,
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: ElevatedButton.icon(
                      onPressed: _iniciarSimulacion,
                      icon: const Icon(Icons.directions_run),
                      label: const Text("Simular Movimiento"),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<List<LatLng>> obtenerRutaPorCalles(
      LatLng origen, LatLng destino) async {
    final apiKey = ApiConfig.getGoogleMapsApiKey();
    final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json?origin=${origen.latitude},${origen.longitude}&destination=${destino.latitude},${destino.longitude}&mode=driving&key=$apiKey');

    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['routes'].isNotEmpty) {
        final polyline = data['routes'][0]['overview_polyline']['points'];
        return decodePolyline(polyline);
      }
    }
    return [];
  }

  List<LatLng> decodePolyline(String encoded) {
    List<LatLng> polyline = [];
    int index = 0, lat = 0, lng = 0;

    while (index < encoded.length) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += dlng;

      polyline.add(LatLng(lat / 1e5, lng / 1e5));
    }

    return polyline;
  }
}

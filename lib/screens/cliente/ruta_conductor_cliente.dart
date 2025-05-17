import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import 'package:taxi_app/components/boton.dart';
import 'package:taxi_app/screens/cliente/resumen_cliente.dart';
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
  LatLng? _ubicacionInicial;
  LatLng? _ubicacionDestino;
  LatLng? _ubicacionConductor;
  String _nombreConductor = "DESCONOCIDO";
  String _direccionConductor = "Obteniendo dirección...";
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  double _progreso = 0.0;
  double _progresoActual = 0.0;
  double? _distanciaTotal;
  bool _notificado = false;
  bool _faseDos = false;
  String? _conductorId;
  Marker? _markerConductor;
  String _placaConductor = "";

  StreamSubscription<DocumentSnapshot>? _solicitudListener;
  StreamSubscription<DocumentSnapshot>? _conductorListener;

  @override
  void initState() {
    super.initState();
    _escucharSolicitud();
  }

  @override
  void dispose() {
    _solicitudListener?.cancel();
    _conductorListener?.cancel();
    super.dispose();
  }

  void _escucharSolicitud() {
    _solicitudListener = FirebaseFirestore.instance
        .collection('solicitud')
        .doc(widget.solicitudId)
        .snapshots()
        .listen((doc) async {
      if (!mounted || !doc.exists) return;
      final data = doc.data()!;
      final nuevoEstado = data['estado'];

      if (nuevoEstado == 'terminado') {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => ResumenSolicitud(solicitudId: widget.solicitudId),
        ));
        return;
      }

      final nuevaFaseDos = nuevoEstado == 'llego';
      if (nuevaFaseDos != _faseDos && mounted) {
        setState(() {
          _faseDos = nuevaFaseDos;
          _distanciaTotal = null;
          _progresoActual = 0.0;
          _progreso = 0.5;
          _notificado = false;
        });
      }

      _ubicacionInicial = LatLng(data['ubicacion_inicial'].latitude,
          data['ubicacion_inicial'].longitude);
      _ubicacionDestino = LatLng(data['ubicacion_seleccionada'].latitude,
          data['ubicacion_seleccionada'].longitude);
      _conductorId = data['conductorId'];
      await _obtenerDatosConductor(_conductorId!);
      _escucharUbicacionConductor(_conductorId!);
    });
  }

  Future<void> _obtenerDatosConductor(String conductorId) async {
    final doc = await FirebaseFirestore.instance
        .collection('conductor')
        .doc(conductorId)
        .get();
    if (doc.exists && mounted) {
      setState(() {
        _nombreConductor = doc['nombre'].toString().toUpperCase();
        _placaConductor = doc['placa']?.toString().toUpperCase() ?? '';
      });
    }
  }

  void _escucharUbicacionConductor(String conductorId) {
    _conductorListener = FirebaseFirestore.instance
        .collection('conductor')
        .doc(conductorId)
        .snapshots()
        .listen((doc) async {
      if (!mounted || !doc.exists || !doc.data()!.containsKey('ubicacion'))
        return;
      GeoPoint geo = doc['ubicacion'];
      LatLng nuevaUbicacion = LatLng(geo.latitude, geo.longitude);
      _ubicacionConductor = nuevaUbicacion;
      _animarMovimientoConductor(nuevaUbicacion);
      await _obtenerDireccionConductor();
      await _actualizarMapa();
      _actualizarProgreso();
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
      _mapController.animateCamera(CameraUpdate.newLatLng(nuevaPos));
    } else {
      final anterior = _markerConductor!;
      double t = 0.0;
      Timer.periodic(const Duration(milliseconds: 16), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }

        t += 0.05;
        if (t >= 1.0) timer.cancel();

        final lat = anterior.position.latitude +
            (nuevaPos.latitude - anterior.position.latitude) * t;
        final lng = anterior.position.longitude +
            (nuevaPos.longitude - anterior.position.longitude) * t;
        final pos = LatLng(lat, lng);

        if (!mounted) return;
        setState(() {
          _markerConductor = anterior.copyWith(positionParam: pos);
          _markers.removeWhere((m) => m.markerId.value == "conductor");
          _markers.add(_markerConductor!);
        });
      });
    }
  }

  Future<void> _obtenerDireccionConductor() async {
    if (_ubicacionConductor != null) {
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          _ubicacionConductor!.latitude,
          _ubicacionConductor!.longitude,
        ).timeout(const Duration(seconds: 5)); // Control explícito de timeout

        if (placemarks.isNotEmpty && mounted) {
          final lugar = placemarks.first;
          setState(() {
            _direccionConductor = "${lugar.street}, ${lugar.locality}";
          });
        }
      } on TimeoutException {
        debugPrint("Timeout al obtener dirección del conductor");
        if (mounted) {
          setState(() {
            _direccionConductor = "Sin dirección (tiempo de espera agotado)";
          });
        }
      } catch (e) {
        debugPrint("Error al obtener dirección del conductor: $e");
        if (mounted) {
          setState(() {
            _direccionConductor = "Dirección no disponible";
          });
        }
      }
    }
  }

  Future<void> _actualizarMapa() async {
    if (_ubicacionConductor == null) return;
    final destino = _faseDos ? _ubicacionDestino : _ubicacionInicial;
    final ruta = await obtenerRutaPorCalles(_ubicacionConductor!, destino!);

    if (!mounted) return;
    setState(() {
      _markers = {
        Marker(
          markerId: MarkerId(_faseDos ? "destino" : "cliente"),
          position: destino,
          icon: BitmapDescriptor.defaultMarkerWithHue(
              _faseDos ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueRed),
        ),
        if (_markerConductor != null) _markerConductor!,
      };
      _polylines = {
        Polyline(
          polylineId: const PolylineId("ruta"),
          color: const Color.fromARGB(255, 255, 251, 0),
          width: 5,
          points: ruta,
        ),
      };
    });

    final bounds = LatLngBounds(
      southwest: LatLng(
        [_ubicacionConductor!.latitude, destino.latitude]
            .reduce((a, b) => a < b ? a : b),
        [_ubicacionConductor!.longitude, destino.longitude]
            .reduce((a, b) => a < b ? a : b),
      ),
      northeast: LatLng(
        [_ubicacionConductor!.latitude, destino.latitude]
            .reduce((a, b) => a > b ? a : b),
        [_ubicacionConductor!.longitude, destino.longitude]
            .reduce((a, b) => a > b ? a : b),
      ),
    );

    _mapController.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
  }

  void _actualizarProgreso() {
    if (_ubicacionConductor == null) return;
    final destino = _faseDos ? _ubicacionDestino : _ubicacionInicial;
    final distanciaActual = Geolocator.distanceBetween(
      _ubicacionConductor!.latitude,
      _ubicacionConductor!.longitude,
      destino!.latitude,
      destino.longitude,
    );

    _distanciaTotal ??= distanciaActual;
    double nuevoProgreso = 1.0 - (distanciaActual / (_distanciaTotal! + 1));
    nuevoProgreso = nuevoProgreso.clamp(0.0, 1.0);

    if (!_notificado && !_faseDos && nuevoProgreso >= 0.95) {
      _notificado = true;
      _mostrarNotificacionDeLlegada();
    }

    _progresoActual += (nuevoProgreso - _progresoActual) * 0.2;

    if (!mounted) return;
    setState(() {
      _progreso =
          _faseDos ? 0.5 + (_progresoActual * 0.5) : _progresoActual * 0.5;
    });
  }

  void _mostrarNotificacionDeLlegada() {
    NotificacionLocal.mostrarNotificacion(
      id: 1,
      titulo: "Conductor cerca",
      cuerpo: "🚖 Tu conductor está a punto de llegar.",
    );
  }

  @override
  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                            Text(
                              "🚖 $_nombreConductor",
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "🚗 Placa: $_placaConductor",
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text("📍 $_direccionConductor"),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text("🛣️ Progreso del viaje:",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  const Center(
                    child: Text(
                      "Recoger                                              Llevar",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      LinearPercentIndicator(
                        lineHeight: 14.0,
                        percent: _progreso,
                        barRadius: const Radius.circular(10),
                        progressColor: Colors.amber,
                        backgroundColor: Colors.grey[300]!,
                        padding: EdgeInsets.zero,
                      ),
                      const Positioned(
                        child: Icon(
                          Icons.arrow_drop_down,
                          color: Colors.black,
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      CustomButton(
                        text: "Detalles",
                        width: MediaQuery.of(context).size.width * 0.35,
                        onPressed: () {
                          debugPrint("Detalles presionado");
                        },
                      ),
                      CustomButton(
                        text: "Emergencia",
                        width: MediaQuery.of(context).size.width * 0.5,
                        onPressed: () {
                          debugPrint("Emergencia presionado");
                        },
                        icon: const Icon(Icons.warning, color: Colors.red),
                      ),
                    ],
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
    try {
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/${origen.longitude},${origen.latitude};${destino.longitude},${destino.latitude}?overview=full&geometries=geojson',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['routes'].isNotEmpty) {
          final coordinates = data['routes'][0]['geometry']['coordinates'];
          return coordinates
              .map<LatLng>((coord) => LatLng(coord[1], coord[0]))
              .toList();
        }
      } else {
        debugPrint("Error en respuesta HTTP: ${response.statusCode}");
      }
    } on TimeoutException {
      debugPrint("Tiempo de espera agotado al conectar con OSRM");
    } on SocketException {
      debugPrint("Error de red: no se pudo conectar con OSRM");
    } catch (e) {
      debugPrint("Error inesperado: $e");
    }

    return [];
  }
}

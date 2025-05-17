import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import 'package:taxi_app/components/boton.dart';
import 'package:taxi_app/screens/conductor/resumen_conductor.dart';
import 'package:url_launcher/url_launcher.dart';

class ConductorRecogida extends StatefulWidget {
  final String solicitudId;

  const ConductorRecogida({Key? key, required this.solicitudId})
      : super(key: key);

  @override
  State<ConductorRecogida> createState() => _ConductorRecogidaState();
}

class _ConductorRecogidaState extends State<ConductorRecogida> {
  GoogleMapController? _mapController;
  LatLng? _ubicacionCliente;
  LatLng? _ubicacionDestino;
  LatLng? _ubicacionConductor;
  String _nombreCliente = "CARGANDO...";
  String _direccionCliente = "Cargando dirección...";
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  double _progreso = 0.0;
  double _progresoActual = 0.0;
  double? _distanciaTotal;
  bool _faseDos = false;
  bool _cercaDelCliente = false;
  bool _cercaDelDestino = false;
  Marker? _markerConductor;
  String? _conductorId;
  Timer? _simulacionTimer;
  bool _llegandoCliente = false;
  bool _terminandoViaje = false;
  StreamSubscription<DocumentSnapshot>? _conductorListener;

  @override
  void initState() {
    super.initState();
    _cargarDatosDesdeSolicitud();
  }

  @override
  void dispose() {
    _simulacionTimer?.cancel();
    _conductorListener?.cancel();
    super.dispose();
  }

  void _cargarDatosDesdeSolicitud() async {
    final doc = await FirebaseFirestore.instance
        .collection('solicitud')
        .doc(widget.solicitudId)
        .get();

    if (!doc.exists) return;

    final data = doc.data()!;
    final clienteId = data['clienteId'];
    final geoInicial = data['ubicacion_inicial'];
    final geoDestino = data['ubicacion_seleccionada'];

    _ubicacionCliente = LatLng(geoInicial.latitude, geoInicial.longitude);
    _ubicacionDestino = LatLng(geoDestino.latitude, geoDestino.longitude);
    _faseDos = data['estado'] == 'llego';

    try {
      final placemarks = await placemarkFromCoordinates(
        geoInicial.latitude,
        geoInicial.longitude,
      );
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        _direccionCliente =
            "${p.street ?? ''}, ${p.locality ?? ''}, ${p.administrativeArea ?? ''}";
      } else {
        _direccionCliente = "Dirección no disponible";
      }
    } catch (_) {
      _direccionCliente = "Dirección no disponible";
    }

    final cliente = await FirebaseFirestore.instance
        .collection('cliente')
        .doc(clienteId)
        .get();
    if (cliente.exists && mounted) {
      setState(() {
        _nombreCliente = cliente['nombre'].toString().toUpperCase();
      });
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _conductorId = user.uid;
      _conductorListener = FirebaseFirestore.instance
          .collection('conductor')
          .doc(user.uid)
          .snapshots()
          .listen((doc) async {
        if (!mounted) return;
        if (doc.exists && doc.data()!.containsKey('ubicacion')) {
          final pos = doc['ubicacion'] as GeoPoint;
          final nuevaUbicacion = LatLng(pos.latitude, pos.longitude);
          _animarMovimientoConductor(nuevaUbicacion);
          _ubicacionConductor = nuevaUbicacion;
          await _actualizarMapa();
          _actualizarProgreso();
        }
      });
    }
  }

  void _animarMovimientoConductor(LatLng nuevaPos) {
    if (_markerConductor == null) {
      _markerConductor = Marker(
        markerId: const MarkerId("conductor"),
        position: nuevaPos,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      );
      _markers.add(_markerConductor!);
    } else {
      final inicio = _markerConductor!.position;
      double t = 0.0;
      Timer.periodic(const Duration(milliseconds: 16), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        t += 0.05;
        if (t >= 1.0) {
          timer.cancel();
          t = 1.0;
        }
        final lat = inicio.latitude + (nuevaPos.latitude - inicio.latitude) * t;
        final lng =
            inicio.longitude + (nuevaPos.longitude - inicio.longitude) * t;
        if (!mounted) return;
        setState(() {
          _markerConductor = _markerConductor!.copyWith(
            positionParam: LatLng(lat, lng),
          );
          _markers.removeWhere((m) => m.markerId.value == "conductor");
          _markers.add(_markerConductor!);
        });
      });
    }
  }

  Future<void> _actualizarMapa() async {
    if (_ubicacionConductor == null) return;

    final destino = _faseDos ? _ubicacionDestino : _ubicacionCliente;
    final puntos = await obtenerRutaPorCalles(_ubicacionConductor!, destino!);

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
          points: puntos,
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

    _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
  }

  void _actualizarProgreso() {
    if (_ubicacionConductor == null) return;

    final destino = _faseDos ? _ubicacionDestino : _ubicacionCliente;
    final distanciaActual = Geolocator.distanceBetween(
      _ubicacionConductor!.latitude,
      _ubicacionConductor!.longitude,
      destino!.latitude,
      destino.longitude,
    );

    _distanciaTotal ??= distanciaActual;
    double nuevoProgreso = 1.0 - (distanciaActual / (_distanciaTotal! + 1));
    nuevoProgreso = nuevoProgreso.clamp(0.0, 1.0);
    _progresoActual += (nuevoProgreso - _progresoActual) * 0.2;

    if (!mounted) return;
    setState(() {
      _progreso =
          _faseDos ? 0.5 + (_progresoActual * 0.5) : _progresoActual * 0.5;
      _cercaDelCliente = !_faseDos && distanciaActual < 50;
      _cercaDelDestino = _faseDos && distanciaActual < 50;
    });
  }

  Future<void> _llegueAlCliente() async {
    await FirebaseFirestore.instance
        .collection('solicitud')
        .doc(widget.solicitudId)
        .update({'estado': 'llego'});

    if (!mounted) return;
    setState(() {
      _faseDos = true;
      _distanciaTotal = null;
      _progresoActual = 0;
      _progreso = 0.5;
    });

    await _actualizarMapa();
  }

  Future<void> _terminarViaje() async {
    Timestamp now = Timestamp.fromDate(DateTime.now());

    final doc = await FirebaseFirestore.instance
        .collection('solicitud')
        .doc(widget.solicitudId)
        .get();

    if (doc.exists) {
      final data = doc.data()!;
      final horaAceptacion = data['hora_aceptacion']?.toDate();
      final nombreCliente = data['clienteId'];
      final direccionInicial = data['ubicacion_inicial'];
      final direccionDestino = data['ubicacion_seleccionada'];

      await FirebaseFirestore.instance.collection('historial viaje').add({
        'solicitudId': widget.solicitudId,
        'fecha_terminacion': now,
        'hora_aceptacion': horaAceptacion,
        'nombre_cliente': nombreCliente,
        'direccion_inicial': direccionInicial,
        'direccion_destino': direccionDestino,
      });

      await FirebaseFirestore.instance
          .collection('solicitud')
          .doc(widget.solicitudId)
          .update({
        'estado': 'terminado',
        'fecha_terminacion': now,
      });

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ResumenConductor(solicitudId: widget.solicitudId),
        ),
      );
    }
  }

  void _simularMovimiento() {
    _simulacionTimer?.cancel();
    final destino = _faseDos ? _ubicacionDestino : _ubicacionCliente;

    _simulacionTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!mounted) {
        _simulacionTimer?.cancel();
        return;
      }

      if (_conductorId == null ||
          _ubicacionConductor == null ||
          destino == null) return;

      final deltaLat = (destino.latitude - _ubicacionConductor!.latitude) * 0.1;
      final deltaLng =
          (destino.longitude - _ubicacionConductor!.longitude) * 0.1;

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
          _progreso >= 1.0) {
        _simulacionTimer?.cancel();
      }
    });
  }

  Future<void> _abrirEnGoogleMaps(LatLng destino) async {
    final url =
        'https://www.google.com/maps/dir/?api=1&destination=${destino.latitude},${destino.longitude}&travelmode=driving';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir Google Maps.')),
      );
    }
  }

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
            flex: 4,
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
                  Text(
                    _faseDos
                        ? "🚗 Llevando al cliente a su destino..."
                        : "📍 Dirígete a recoger al cliente",
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 20),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.grey,
                        child: Icon(Icons.person, color: Colors.white),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("🚶 $_nombreCliente",
                                style: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text("📍 $_direccionCliente"),
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
                      if (!_faseDos)
                        CustomButton(
                          text: "Ya llegué",
                          onPressed: _cercaDelCliente
                              ? () => _llegueAlCliente()
                              : null,
                          isLoading: _llegandoCliente,
                          width: 140,
                          height: 45,
                          fontSize: 14,
                          icon: const Icon(Icons.location_on,
                              color: Colors.white),
                        ),
                      if (_faseDos)
                        CustomButton(
                          text: "Terminar viaje",
                          onPressed:
                              _cercaDelDestino ? () => _terminarViaje() : null,
                          isLoading: _terminandoViaje,
                          width: 170,
                          height: 45,
                          fontSize: 14,
                          icon: const Icon(Icons.flag, color: Colors.white),
                        ),
                      CustomButton(
                        text: "Simular",
                        onPressed: _simularMovimiento,
                        width: 130,
                        height: 45,
                        fontSize: 14,
                        icon: const Icon(Icons.directions_run,
                            color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  CustomButton(
                    text: "Abrir en Google Maps",
                    onPressed: () {
                      final destino =
                          _faseDos ? _ubicacionDestino : _ubicacionCliente;
                      if (destino != null) _abrirEnGoogleMaps(destino);
                    },
                    width: double.infinity,
                    height: 45,
                    fontSize: 14,
                    icon: const Icon(Icons.map, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<List<LatLng>> obtenerRutaPorCalles(LatLng origen, LatLng destino) async {
  final url = Uri.parse(
    'https://router.project-osrm.org/route/v1/driving/${origen.longitude},${origen.latitude};${destino.longitude},${destino.latitude}?overview=full&geometries=geojson',
  );

  try {
    final response = await http.get(
      url,
      headers: {
        'User-Agent': 'FlutterApp/1.0',
        'Accept': 'application/json',
      },
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['routes'].isNotEmpty) {
        final coordinates = data['routes'][0]['geometry']['coordinates'];
        return coordinates
            .map<LatLng>((coord) => LatLng(coord[1], coord[0]))
            .toList();
      }
    } else {
      debugPrint("HTTP error: ${response.statusCode}");
    }
  } on SocketException catch (e) {
    debugPrint("No se pudo conectar con OSRM: $e");
  } on TimeoutException {
    debugPrint("Tiempo de espera agotado al conectar con OSRM");
  } on http.ClientException catch (e) {
    debugPrint("ClientException: $e");
  } catch (e) {
    debugPrint("Otro error: $e");
  }

  return [];
}

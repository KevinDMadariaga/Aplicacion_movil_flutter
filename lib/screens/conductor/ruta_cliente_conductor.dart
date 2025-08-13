import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geocoding/geocoding.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import 'package:taxi_app/components/boton.dart';
import 'package:taxi_app/screens/conductor/resumen_conductor.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:geolocator_android/geolocator_android.dart';

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
  bool _isMoving = false; // Variable para controlar si el conductor se mueve
  late Timer _moveTimer; // Timer para controlar el movimiento
  StreamSubscription<DocumentSnapshot>? _conductorListener;
  StreamSubscription<Position>? _positionStream;

  @override
  void initState() {
    super.initState();
    _cargarDatosDesdeSolicitud();
    _iniciarRastreoUbicacion();
  }

  @override
  void dispose() {
    _simulacionTimer?.cancel();
    _conductorListener?.cancel();
    _positionStream?.cancel();
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

  Future<void> _abrirGoogleMapsExternamente() async {
    final origen = _ubicacionConductor;
    final destino = _faseDos ? _ubicacionDestino : _ubicacionCliente;

    if (origen == null || destino == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Ubicación no disponible")));
      return;
    }

    final url = Uri.parse(
      "https://www.google.com/maps/dir/?api=1"
      "&origin=${origen.latitude},${origen.longitude}"
      "&destination=${destino.latitude},${destino.longitude}"
      "&travelmode=driving",
    );

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No se pudo abrir Google Maps")),
      );
    }
  }

  void _animarMovimientoConductor(LatLng nuevaPos) async {
    if (_markerConductor == null) {
      // Cargar la imagen como icono
      final BitmapDescriptor customIcon = await BitmapDescriptor.fromAssetImage(
        ImageConfiguration(size: Size(50, 50)), // Ajusta el tamaño aquí
        'assets/img/taxi_icon.png', // Ruta de tu imagen
      );

      // Crear el marcador con la imagen personalizada
      _markerConductor = Marker(
        markerId: const MarkerId("conductor"),
        position: nuevaPos,
        icon: customIcon,
      );
      _markers.add(_markerConductor!);
    } else {
      final inicio = _markerConductor!.position;
      double t = 0.0;
      Timer.periodic(const Duration(milliseconds: 100), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        t += 0.02;
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

    // Cargar el icono del marcador para destino o cliente
    final BitmapDescriptor destinoIcon = await BitmapDescriptor.fromAssetImage(
      ImageConfiguration(size: Size(50, 50)), // Ajusta el tamaño aquí
      _faseDos
          ? 'assets/img/map_pin_red.png'
          : 'assets/img/map_pin_blue.png', // Ruta de la imagen para destino o cliente
    );

    // Cargar el icono del marcador para conductor (si existe)
    final BitmapDescriptor conductorIcon =
        await BitmapDescriptor.fromAssetImage(
          ImageConfiguration(size: Size(50, 50)),
          'assets/img/taxi_icon.png', // Ruta de la imagen para conductor
        );

    if (!mounted) return;
    setState(() {
      _markers = {
        Marker(
          markerId: MarkerId(_faseDos ? "destino" : "cliente"),
          position: destino,
          icon: destinoIcon, // Usamos la imagen personalizada
        ),
        if (_markerConductor != null)
          _markerConductor!.copyWith(
            iconParam: conductorIcon,
          ), // Actualiza el icono del marcador del conductor
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
        [
          _ubicacionConductor!.latitude,
          destino.latitude,
        ].reduce((a, b) => a < b ? a : b),
        [
          _ubicacionConductor!.longitude,
          destino.longitude,
        ].reduce((a, b) => a < b ? a : b),
      ),
      northeast: LatLng(
        [
          _ubicacionConductor!.latitude,
          destino.latitude,
        ].reduce((a, b) => a > b ? a : b),
        [
          _ubicacionConductor!.longitude,
          destino.longitude,
        ].reduce((a, b) => a > b ? a : b),
      ),
    );

    _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
  }

  Future<List<LatLng>> obtenerRutaPorCalles(
    LatLng origen,
    LatLng destino,
  ) async {
    final url = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/${origen.longitude},${origen.latitude};${destino.longitude},${destino.latitude}?overview=full&geometries=geojson',
    );

    try {
      final response = await http
          .get(
            url,
            headers: {
              'User-Agent': 'FlutterApp/1.0',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 10));

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
      _progreso = _faseDos
          ? 0.5 + (_progresoActual * 0.5)
          : _progresoActual * 0.5;
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

  Future<void> _iniciarRastreoUbicacion() async {
    LocationPermission permiso = await Geolocator.checkPermission();
    if (permiso == LocationPermission.denied ||
        permiso == LocationPermission.deniedForever) {
      permiso = await Geolocator.requestPermission();
      if (permiso != LocationPermission.always &&
          permiso != LocationPermission.whileInUse) {
        debugPrint("Permiso de ubicación no concedido");
        return;
      }
    }

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    _positionStream =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (Position position) {
            if (!mounted || _conductorId == null) return;

            final nuevaPos = LatLng(position.latitude, position.longitude);
            FirebaseFirestore.instance
                .collection('conductor')
                .doc(_conductorId)
                .update({
                  'ubicacion': GeoPoint(nuevaPos.latitude, nuevaPos.longitude),
                  'actualizado': FieldValue.serverTimestamp(),
                });

            _ubicacionConductor = nuevaPos;
            _animarMovimientoConductor(nuevaPos);
            _actualizarMapa();
            _actualizarProgreso();
          },
        );

    debugPrint("[ConductorRecogida] Rastreo activo incluso en segundo plano");
  }

  Future<void> _terminarViaje() async {
    Timestamp now = Timestamp.fromDate(DateTime.now());

    await FirebaseFirestore.instance
        .collection('solicitud')
        .doc(widget.solicitudId)
        .update({'estado': 'terminado', 'fecha_terminacion': now});

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ResumenConductor(solicitudId: widget.solicitudId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final fontSize = screenWidth * 0.044;

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            flex: 5,
            child: GoogleMap(
              initialCameraPosition: const CameraPosition(
                target: LatLng(0, 0),
                zoom: 14,
              ),
              markers: _markers,
              polylines: _polylines,
              onMapCreated: (controller) => _mapController = controller,
              myLocationEnabled: false,
              zoomControlsEnabled: false,
            ),
          ),
          Expanded(
            flex: 4,
            child: Stack(
              children: [
                Container(
                  padding: EdgeInsets.all(screenWidth * 0.050),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                    boxShadow: [
                      BoxShadow(blurRadius: 10, color: Colors.black12),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _faseDos
                            ? "🚗 Llevando al cliente a su destino..."
                            : "📍 Dirígete a recoger al cliente",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: fontSize + 2,
                        ),
                      ),
                      SizedBox(height: screenHeight * 0.01),
                      Row(
                        children: [
                          CircleAvatar(
                            radius: screenWidth * 0.08,
                            backgroundColor: Colors.grey,
                            child: Icon(Icons.person, size: screenWidth * 0.08),
                          ),
                          SizedBox(width: screenWidth * 0.04),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "🚶 $_nombreCliente",
                                  style: TextStyle(
                                    fontSize: fontSize,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: screenHeight * 0.005),
                                Text(
                                  "📍 $_direccionCliente",
                                  style: TextStyle(fontSize: fontSize * 0.9),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: screenHeight * 0.015),
                      Text(
                        "🛣️ Progreso del viaje:",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: fontSize,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Center(
                        child: Text(
                          "Recoger                                              Llevar",
                          style: TextStyle(
                            fontSize: fontSize * 0.75,
                            fontWeight: FontWeight.w500,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          LinearPercentIndicator(
                            lineHeight: screenHeight * 0.017,
                            percent: _progreso,
                            barRadius: const Radius.circular(10),
                            progressColor: Colors.amber,
                            backgroundColor: Colors.grey[300]!,
                            padding: EdgeInsets.zero,
                          ),
                          Icon(
                            Icons.arrow_drop_down,
                            color: Colors.black,
                            size: fontSize + 6,
                          ),
                        ],
                      ),
                      SizedBox(height: screenHeight * 0.015),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          if (!_faseDos)
                            CustomButton(
                              text: "Ya llegué",
                              onPressed: _cercaDelCliente
                                  ? _llegueAlCliente
                                  : null,
                              isLoading: _llegandoCliente,
                              width: screenWidth * 0.45,
                              height: screenHeight * 0.06,
                              fontSize: fontSize,
                              icon: Icon(
                                Icons.location_on,
                                size: fontSize,
                                color: Colors.white,
                              ),
                            ),
                          if (_faseDos)
                            CustomButton(
                              text: "Terminar viaje",
                              onPressed: _cercaDelDestino
                                  ? _terminarViaje
                                  : null,
                              isLoading: _terminandoViaje,
                              width: screenWidth * 0.42,
                              height: screenHeight * 0.06,
                              fontSize: fontSize,
                            ),
                          CustomButton(
                            text: "Maps",
                            onPressed: _abrirGoogleMapsExternamente,
                            isLoading: false,
                            width: screenWidth * 0.30,
                            height: screenHeight * 0.06,
                            fontSize: fontSize,
                            icon: Icon(
                              Icons.map_outlined,
                              size: fontSize,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

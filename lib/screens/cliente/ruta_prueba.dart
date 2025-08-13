import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geocoding/geocoding.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import 'package:taxi_app/components/boton.dart';
import 'package:taxi_app/main.dart';
import 'package:taxi_app/screens/cliente/resumen_cliente.dart';
import 'package:vibration/vibration.dart';

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

          final bool notiFuera = data['fueraDeCasa'] == true;
          if (notiFuera && !_notificado) {
            _notificado = true;
            _mostrarNotificacionFueraDeCasa();
          }

          final nuevoEstado = data['estado'];
          if (nuevoEstado == 'terminado') {
            if (!mounted) return;
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) =>
                    ResumenSolicitud(solicitudId: widget.solicitudId),
              ),
            );
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

          _ubicacionCliente = LatLng(
            data['ubicacion_inicial'].latitude,
            data['ubicacion_inicial'].longitude,
          );
          _ubicacionDestino = LatLng(
            data['ubicacion_seleccionada'].latitude,
            data['ubicacion_seleccionada'].longitude,
          );
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

  // Este método escucha los cambios en la ubicación del conductor
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
          _animarMovimientoConductor(nuevaUbicacion); // Actualiza la ubicación
          await _obtenerDireccionConductor();
          await _actualizarMapa();
          _actualizarProgreso();
        });
  }

  void _animarMovimientoConductor(LatLng nuevaPos) async {
    if (_markerConductor == null) {
      // Cargar la imagen como icono
      final BitmapDescriptor customIcon = await BitmapDescriptor.fromAssetImage(
        ImageConfiguration(size: Size(50, 50)), // Ajusta el tamaño aquí
        'assets/img/icon_taxi.png', // Ruta de tu imagen
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

  Future<void> _obtenerDireccionConductor() async {
    if (_ubicacionConductor != null) {
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          _ubicacionConductor!.latitude,
          _ubicacionConductor!.longitude,
        ).timeout(const Duration(seconds: 5));

        if (placemarks.isNotEmpty && mounted) {
          final lugar = placemarks.first;
          setState(() {
            _direccionConductor = "${lugar.street}, ${lugar.locality}";
          });
        }
      } catch (_) {
        setState(() {
          _direccionConductor = "Dirección no disponible";
        });
      }
    }
  }

  Future<void> _actualizarMapa() async {
    if (_ubicacionConductor == null) return;

    final destino = _faseDos ? _ubicacionDestino : _ubicacionCliente;
    final ruta = await obtenerRutaPorCalles(_ubicacionConductor!, destino!);

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
          'assets/img/icon_taxi.png', // Ruta de la imagen para conductor
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
          points: ruta,
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

    _mapController.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
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

    if (!_notificado && !_faseDos && nuevoProgreso >= 0.95) {
      _notificado = true;
      _mostrarNotificacionLocal();
    }

    _progresoActual += (nuevoProgreso - _progresoActual) * 0.2;

    if (!mounted) return;
    setState(() {
      _progreso = _faseDos
          ? 0.5 + (_progresoActual * 0.5)
          : _progresoActual * 0.5;
    });
  }

  Future<void> _mostrarNotificacionLocal() async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'canal_solicitudes', // ID del canal
          'Solicitudes', // Nombre visible del canal
          importance: Importance.max,
          priority: Priority.high,
          playSound: true, // 🔊 Sonido predeterminado del sistema
          enableVibration: true, // ✅ Activa vibración
          icon: '@mipmap/ic_launcher', // Icono predeterminado
        );

    const NotificationDetails notiDetails = NotificationDetails(
      android: androidDetails,
    );

    await flutterLocalNotificationsPlugin.show(
      0,
      '🚖 Conductor cerca', // TÍTULO
      'Tu conductor está por llegar.', // MENSAJE
      notiDetails,
    );

    // ✅ Vibración predeterminada
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(); // vibración simple estándar
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final fontSize = screenWidth * 0.045;
    final iconSize = screenWidth * 0.07;

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
            flex: 3,
            child: Container(
              padding: EdgeInsets.all(screenWidth * 0.04),
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
                              "🚖 $_nombreConductor",
                              style: TextStyle(
                                fontSize: fontSize,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: screenHeight * 0.005),
                            Text(
                              "🚗 Placa: $_placaConductor",
                              style: TextStyle(
                                fontSize: fontSize * 0.95,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: screenHeight * 0.005),
                            Text(
                              "📍 $_direccionConductor",
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
                  SizedBox(height: screenHeight * 0.008),
                  const Center(
                    child: Text(
                      "Llegada                                              Destino",
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
                        lineHeight: screenHeight * 0.015,
                        percent: _progreso,
                        barRadius: const Radius.circular(10),
                        progressColor: Colors.amber,
                        backgroundColor: Colors.grey[300]!,
                        padding: EdgeInsets.zero,
                      ),
                      Icon(
                        Icons.arrow_drop_down,
                        color: Colors.black,
                        size: iconSize,
                      ),
                    ],
                  ),
                  SizedBox(height: screenHeight * 0.015),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      CustomButton(
                        text: "Detalles",
                        width: screenWidth * 0.35,
                        height: screenHeight * 0.06,
                        fontSize: fontSize,
                        onPressed: () {
                          debugPrint("Detalles presionado");
                        },
                      ),
                      CustomButton(
                        text: "Emergencia",
                        width: screenWidth * 0.5,
                        height: screenHeight * 0.06,
                        fontSize: fontSize,
                        icon: Icon(
                          Icons.warning,
                          size: iconSize,
                          color: Colors.red,
                        ),
                        onPressed: () {
                          debugPrint("Emergencia presionado");
                        },
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

  Future<void> _mostrarNotificacionFueraDeCasa() async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'noti_fuera_casa',
          'Notificación Fuera de Casa',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          icon: '@mipmap/ic_launcher',
        );

    const NotificationDetails notiDetails = NotificationDetails(
      android: androidDetails,
    );

    await flutterLocalNotificationsPlugin.show(
      1,
      '🚖 Tu conductor ha llegado',
      'Tu conductor está afuera de tu casa',
      notiDetails,
    );

    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(duration: 800);
    }
  }
}

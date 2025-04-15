import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmap;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:lottie/lottie.dart' as lottie;
import 'package:percent_indicator/linear_percent_indicator.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart' show rootBundle;

class DestinoClienteConductor extends StatefulWidget {
  final LatLng ubicacionInicial;
  final LatLng ubicacionDestino;
  final String solicitudId;

  const DestinoClienteConductor({
    Key? key,
    required this.ubicacionInicial,
    required this.ubicacionDestino,
    required this.solicitudId,
  }) : super(key: key);

  @override
  _DestinoClienteConductorState createState() =>
      _DestinoClienteConductorState();
}

class _DestinoClienteConductorState extends State<DestinoClienteConductor> {
  late gmap.GoogleMapController? _mapController;
  Set<gmap.Marker> _markers = {}; // Marcadores del mapa
  Set<gmap.Polyline> _polylines = {}; // Polilíneas para la ruta
  String _nombreConductor = "CARGANDO...";
  String _direccionDestino = "Obteniendo dirección...";
  String _estadoViaje = "Calculando...";
  double _progreso = 0.0;
  bool _mostrarEstrella = false;
  final AudioPlayer _audioPlayer = AudioPlayer();
  gmap.Marker? _taxiMarker; // Marcador para la ubicación del taxi

  @override
  void initState() {
    super.initState();
    _cargarMarcadores();
    _cargarRuta();
    _ajustarCamara();
    _obtenerDatosConductor();
    _iniciarSeguimiento();
  }

  // Cargar marcadores (inicial y destino)
  void _cargarMarcadores() {
    _markers.add(gmap.Marker(
      markerId: const gmap.MarkerId("destino"),
      position: widget.ubicacionDestino,
      icon: gmap.BitmapDescriptor.defaultMarkerWithHue(
          gmap.BitmapDescriptor.hueGreen),
    ));
    _taxiMarker = gmap.Marker(
      markerId: const gmap.MarkerId("taxi"),
      position: widget.ubicacionInicial,
      icon: gmap.BitmapDescriptor.defaultMarkerWithHue(
          gmap.BitmapDescriptor.hueBlue),
    );
    _markers.add(_taxiMarker!);
  }

  // Cargar la ruta entre el origen y destino
  void _cargarRuta() {
    _polylines.add(gmap.Polyline(
      polylineId: const gmap.PolylineId("ruta"),
      color: Colors.blue,
      width: 5,
      points: [widget.ubicacionInicial, widget.ubicacionDestino],
    ));
  }

  // Ajustar la cámara del mapa para que se enfoque en la ruta
  void _ajustarCamara() {
    final latitudes = [
      widget.ubicacionInicial.latitude,
      widget.ubicacionDestino.latitude
    ];
    final longitudes = [
      widget.ubicacionInicial.longitude,
      widget.ubicacionDestino.longitude
    ];

    final bounds = gmap.LatLngBounds(
      southwest: gmap.LatLng(
        latitudes.reduce((a, b) => a < b ? a : b),
        longitudes.reduce((a, b) => a < b ? a : b),
      ),
      northeast: gmap.LatLng(
        latitudes.reduce((a, b) => a > b ? a : b),
        longitudes.reduce((a, b) => a > b ? a : b),
      ),
    );

    _mapController
        ?.animateCamera(gmap.CameraUpdate.newLatLngBounds(bounds, 80));
  }

  // Obtener los datos del conductor y la dirección seleccionada
  Future<void> _obtenerDatosConductor() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('solicitud')
          .doc(widget.solicitudId)
          .get();

      if (!doc.exists || !doc.data()!.containsKey('conductorId')) return;

      final conductorId = doc['conductorId'];

      final conductorDoc = await FirebaseFirestore.instance
          .collection('conductor')
          .doc(conductorId)
          .get();

      if (conductorDoc.exists && conductorDoc.data()!.containsKey('nombre')) {
        setState(() {
          _nombreConductor = conductorDoc['nombre'].toString().toUpperCase();
        });
      }

      if (doc.data()!.containsKey('direccion_seleccionada')) {
        setState(() {
          _direccionDestino = doc['direccion_seleccionada'];
        });
      }
    } catch (e) {
      debugPrint("❌ Error al obtener datos del conductor: $e");
    }
  }

  // Iniciar el seguimiento del taxi y calcular el progreso
  void _iniciarSeguimiento() {
    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(distanceFilter: 10),
    ).listen((posicion) async {
      double distancia = Geolocator.distanceBetween(
        posicion.latitude,
        posicion.longitude,
        widget.ubicacionDestino.latitude,
        widget.ubicacionDestino.longitude,
      );

      String estado = "En camino";
      if (distancia < 200) {
        estado = "Llegando...";
        if (!_mostrarEstrella) {
          final bytes = await rootBundle.load('assets/song/ding.mp3');
          final audioSource = BytesSource(bytes.buffer.asUint8List());
          _audioPlayer.play(audioSource);
          setState(() {
            _mostrarEstrella = true;
          });
        }
      } else if (distancia < 1000) {
        estado = "Cerca del destino";
      }

      double distanciaTotal = Geolocator.distanceBetween(
        widget.ubicacionInicial.latitude,
        widget.ubicacionInicial.longitude,
        widget.ubicacionDestino.latitude,
        widget.ubicacionDestino.longitude,
      );

      double progreso = 1.0 - (distancia / distanciaTotal);
      if (!mounted) return;
      setState(() {
        _estadoViaje = estado;
        _progreso = progreso.clamp(0.0, 1.0);
        _taxiMarker = _taxiMarker?.copyWith(
          positionParam: gmap.LatLng(posicion.latitude, posicion.longitude),
        );
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Tu viaje está en curso")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.4,
                child: gmap.GoogleMap(
                  initialCameraPosition: gmap.CameraPosition(
                    target: widget.ubicacionInicial,
                    zoom: 14,
                  ),
                  markers: _markers,
                  polylines: _polylines,
                  onMapCreated: (controller) {
                    _mapController = controller;
                  },
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 35,
                  backgroundImage: AssetImage("assets/img/default_avatar.png"),
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
                        "📍 $_direccionDestino",
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "🧭 Estado: $_estadoViaje",
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: LinearPercentIndicator(
              animation: true,
              lineHeight: 20.0,
              percent: _progreso,
              barRadius: const Radius.circular(10),
              progressColor: Colors.green,
              backgroundColor: Colors.grey[300]!,
            ),
          ),
          if (_mostrarEstrella)
            lottie.Lottie.asset('assets/json/finish.json',
                width: 150, repeat: false),
        ],
      ),
    );
  }
}

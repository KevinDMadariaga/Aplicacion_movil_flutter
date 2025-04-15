import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:taxi_app/components/boton.dart';
import 'package:taxi_app/screens/conductor/resumen_conductor.dart';

class DestinoConductor extends StatefulWidget {
  final LatLng ubicacionConductor;
  final LatLng ubicacionDestino;
  final String solicitudId;

  const DestinoConductor({
    Key? key,
    required this.ubicacionConductor,
    required this.ubicacionDestino,
    required this.solicitudId,
  }) : super(key: key);

  @override
  _DestinoConductorState createState() => _DestinoConductorState();
}

class _DestinoConductorState extends State<DestinoConductor> {
  late GoogleMapController _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  String _direccionSeleccionada = "Obteniendo dirección...";
  String _nombreCliente = "Cargando...";
  bool _cargando = false;

  @override
  void initState() {
    super.initState();
    _cargarMarcadores();
    _cargarRuta();
    _obtenerDatosCliente();
  }

  void _cargarMarcadores() {
    setState(() {
      _markers.add(Marker(
        markerId: const MarkerId("ubicacion_conductor"),
        position: widget.ubicacionConductor,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        infoWindow: const InfoWindow(title: "🚖 Conductor"),
      ));

      _markers.add(Marker(
        markerId: const MarkerId("ubicacion_destino"),
        position: widget.ubicacionDestino,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: const InfoWindow(title: "🏁 Destino"),
      ));
    });
  }

  void _cargarRuta() {
    setState(() {
      _polylines.add(Polyline(
        polylineId: const PolylineId("ruta"),
        color: Colors.green,
        width: 5,
        points: [
          widget.ubicacionConductor,
          widget.ubicacionDestino,
        ],
      ));
    });
  }

  void _ajustarCamara() {
    final latitudes = [
      widget.ubicacionConductor.latitude,
      widget.ubicacionDestino.latitude
    ];
    final longitudes = [
      widget.ubicacionConductor.longitude,
      widget.ubicacionDestino.longitude
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mapController.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
    });
  }

  Future<void> _obtenerDatosCliente() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('solicitud')
          .doc(widget.solicitudId)
          .get();

      if (!doc.exists || !doc.data()!.containsKey('clienteId')) {
        debugPrint("⚠️ No se encontró el campo 'clienteId' en la solicitud.");
        return;
      }

      final data = doc.data();
      final clienteId = data!['clienteId'];

      // Traer nombre del cliente
      final clienteSnapshot = await FirebaseFirestore.instance
          .collection('cliente')
          .doc(clienteId)
          .get();

      if (clienteSnapshot.exists &&
          clienteSnapshot.data()!.containsKey('nombre')) {
        setState(() {
          _nombreCliente = clienteSnapshot['nombre'].toString().toUpperCase();
        });
      } else {
        debugPrint("⚠️ El documento del cliente no tiene 'nombre'");
        setState(() {
          _nombreCliente = "Nombre no disponible";
        });
      }

      // Traer dirección seleccionada
      if (data.containsKey('direccion_seleccionada')) {
        setState(() {
          _direccionSeleccionada = data['direccion_seleccionada'];
        });
      } else {
        setState(() {
          _direccionSeleccionada = "Dirección no disponible";
        });
      }
    } catch (e) {
      debugPrint("❌ Error al obtener datos del cliente: $e");
      setState(() {
        _nombreCliente = "Error al cargar";
        _direccionSeleccionada = "Error al cargar dirección";
      });
    }
  }

  Future<void> _finalizarSolicitud() async {
    if (!mounted) return;
    setState(() => _cargando = true);

    try {
      await FirebaseFirestore.instance
          .collection('solicitud')
          .doc(widget.solicitudId)
          .update({
        'estado': 'terminado',
        'timestamp_terminado': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Solicitud terminada exitosamente.")),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ResumenConductor(
            solicitudId: widget.solicitudId,
          ),
        ),
      );
    } catch (e) {
      debugPrint("Error al finalizar solicitud: $e");
      if (!mounted) return;
      setState(() => _cargando = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error al finalizar la solicitud: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Destino del Conductor")),
      body: Column(
        children: [
          Container(
            height: MediaQuery.of(context).size.height * 0.5,
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: widget.ubicacionConductor,
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
          Padding(
            padding: const EdgeInsets.all(16.0),
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
                        "🧍 Cliente: $_nombreCliente",
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "📍 Dirección seleccionada:\n$_direccionSeleccionada",
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: _cargando
                ? const CircularProgressIndicator()
                : CustomButton(
                    text: 'Finalizar Solicitud',
                    onPressed: _finalizarSolicitud,
                    width: 220,
                    height: 50,
                    fontSize: 16,
                  ),
          ),
        ],
      ),
    );
  }
}

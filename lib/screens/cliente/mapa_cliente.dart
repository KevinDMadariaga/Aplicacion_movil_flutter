import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_place/google_place.dart';
import 'package:taxi_app/components/boton.dart';
import 'package:taxi_app/components/colores.dart';
import 'package:taxi_app/screens/cliente/mapa_cliente_logica.dart';
import 'package:taxi_app/screens/cliente/ruta_conductor_cliente.dart';
import 'package:taxi_app/services/api_google.dart';
import 'package:taxi_app/screens/home.dart';

class MapaCliente extends StatefulWidget {
  const MapaCliente({super.key});

  @override
  State<MapaCliente> createState() => _MapaClienteState();
}

class _MapaClienteState extends State<MapaCliente> {
  late GoogleMapController _mapController;
  final GooglePlace _googlePlace = GooglePlace(ApiConfig.getGoogleMapsApiKey());
  LatLng? _userLocation;
  LatLng? _ultimaUbicacionSeleccionada;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  final TextEditingController _searchController = TextEditingController();
  String _direccionInicial = "Cargando dirección...";
  String _ultimaDireccionSeleccionada = "";
  bool _mostrarBotonTaxi = true;
  String? _solicitudId;
  bool _mostrarInformacionUbicacion = false;

  @override
  void initState() {
    super.initState();
    _inicializarUbicacion();
  }

  Future<void> _inicializarUbicacion() async {
    final result = await obtenerUbicacionUsuario();
    if (result.location != null && mounted) {
      setState(() {
        _userLocation = result.location;
        _direccionInicial = result.direccion;
      });
      _mapController.animateCamera(
        CameraUpdate.newLatLngZoom(_userLocation!, 16.0),
      );
    } else {
      _mostrarError(context, result.error);
    }
  }

  void _mostrarError(BuildContext context, String mensaje) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(mensaje)));
  }

  void _ajustarVistaMarcadores() {
    if (_userLocation == null || _ultimaUbicacionSeleccionada == null) return;
    final bounds =
        crearLimitesMapa(_userLocation!, _ultimaUbicacionSeleccionada!);
    _mapController.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));
  }

  Future<void> _mostrarCuadroBusqueda() async {
    final resultado = await mostrarBusquedaUbicacion(
      context: context,
      googlePlace: _googlePlace,
      userLocation: _userLocation,
    );

    if (resultado != null && mounted) {
      // Obtener ruta real por calles usando Google Directions API
      final ruta =
          await obtenerRutaPorCalles(_userLocation!, resultado.location!);
      print("✅ Ruta recibida con ${ruta.length} puntos");

      setState(() {
        _ultimaUbicacionSeleccionada = resultado.location;
        _ultimaDireccionSeleccionada = resultado.direccion;
        _mostrarInformacionUbicacion = true;
        _mostrarBotonTaxi = false;

        _markers
          ..removeWhere((m) => m.markerId.value == "ubicacion_seleccionada")
          ..add(crearMarkerSeleccionado(resultado));

        _polylines
          ..clear()
          ..add(Polyline(
            polylineId: const PolylineId('ruta'),
            points: ruta,
            color: const Color.fromARGB(255, 46, 46, 46),
            width: 5,
          ));
      });

      _ajustarVistaMarcadores();
    }
  }

  Future<void> _cancelarSolicitud() async {
    if (_solicitudId != null) {
      final ref =
          FirebaseFirestore.instance.collection('solicitud').doc(_solicitudId);
      final snapshot = await ref.get();
      if (snapshot.exists) {
        await ref.update({'estado': 'cancelada'});
        _mostrarMensaje('Solicitud cancelada correctamente');
      }
    }
    _limpiarUI();
  }

  void _limpiarUI() {
    setState(() {
      _solicitudId = null;
      _mostrarInformacionUbicacion = false;
      _mostrarBotonTaxi = true;
      _markers.removeWhere((m) => m.markerId.value == "ubicacion_seleccionada");
      _polylines.clear();
      if (_userLocation != null) {
        _mapController
            .animateCamera(CameraUpdate.newLatLngZoom(_userLocation!, 15.0));
      }
    });
  }

  void _mostrarMensaje(String mensaje) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(mensaje)));
  }

  Future<void> _aceptarSolicitud() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => crearDialogoCarga(context, _cancelarSolicitud),
      );

      final solicitudId = await crearSolicitudFirebase(_userLocation!,
          _ultimaUbicacionSeleccionada!, _ultimaDireccionSeleccionada);
      if (solicitudId != null) {
        setState(() => _solicitudId = solicitudId);
        _escucharSolicitud(solicitudId);
      }
    } catch (e) {
      Navigator.of(context, rootNavigator: true).pop();
      _mostrarMensaje('Error al solicitar viaje: $e');
    }
  }

  void _escucharSolicitud(String solicitudId) {
    FirebaseFirestore.instance
        .collection('solicitud')
        .doc(solicitudId)
        .snapshots()
        .listen((doc) {
      if (!doc.exists) return;

      final estado = doc['estado'] ?? '';
      if (estado == 'cancelada') {
        FirebaseFirestore.instance
            .collection('solicitud')
            .doc(solicitudId)
            .delete();
        _mostrarMensaje('Solicitud cancelada y eliminada.');
        _limpiarUI();
      }

      if (estado == 'aceptada') {
        Navigator.of(context, rootNavigator: true).pop();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ClienteRecogida(
              solicitudId: solicitudId,
            ),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
          backgroundColor: Colores.amarillo, title: const Text("Mapa Cliente")),
      drawer: crearDrawerUsuario(user, context),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _userLocation ?? const LatLng(8.2595534, -73.353469),
              zoom: 15.0,
            ),
            onMapCreated: (controller) => _mapController = controller,
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: true,
          ),
          if (_mostrarInformacionUbicacion)
            posicionarInfoUbicacion(
              _direccionInicial,
              _ultimaDireccionSeleccionada,
              onCancelar: _cancelarSolicitud,
              onAceptar: _aceptarSolicitud,
            ),
          if (_mostrarBotonTaxi)
            Positioned(
              bottom: 80,
              left: MediaQuery.of(context).size.width * 0.3,
              child: CustomButton(
                text: 'Buscar Taxi',
                onPressed: _mostrarCuadroBusqueda,
                width: 160,
                height: 50,
                fontSize: 16,
              ),
            )
        ],
      ),
    );
  }
}

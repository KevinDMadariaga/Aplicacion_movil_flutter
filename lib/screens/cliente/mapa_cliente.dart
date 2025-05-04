import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:taxi_app/components/boton.dart';
import 'package:taxi_app/components/colores.dart';
import 'package:taxi_app/screens/cliente/mapa_cliente_logica.dart';
import 'package:taxi_app/screens/cliente/ruta_conductor_cliente.dart';
import 'package:diacritic/diacritic.dart'; // Importa el paquete diacritic
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;


class MapaCliente extends StatefulWidget {
  const MapaCliente({super.key});

  @override
  State<MapaCliente> createState() => _MapaClienteState();
}

class _MapaClienteState extends State<MapaCliente> {
  late GoogleMapController _mapController;
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

  // Normaliza texto (elimina tildes y convierte a minúsculas)
  String normalizarTexto(String texto) {
    String textoSinTildes = removeDiacritics(texto);
    return textoSinTildes.toLowerCase();
  }

  Future<UbicacionResultado?> mostrarBusquedaUbicacion({
    required BuildContext context,
    required LatLng? userLocation,
  }) async {
    List<QueryDocumentSnapshot<Map<String, dynamic>>> sugerencias = [];
    final TextEditingController searchController = TextEditingController();

    return await showModalBottomSheet<UbicacionResultado>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            void buscarUbicaciones(String query) async {
              if (query.isEmpty) {
                setStateModal(() => sugerencias = []);
                return;
              }
              // Normalizamos el texto de la búsqueda
              String queryNormalizada = normalizarTexto(query);

              // Obtenemos las ubicaciones de Firebase y las filtramos
              final snapshot = await FirebaseFirestore.instance
                  .collection('ubicaciones')
                  .get();

              final filtered = snapshot.docs.where((lugar) {
                String nombreNormalizado = normalizarTexto(lugar['nombre']);
                return nombreNormalizado.contains(queryNormalizada);
              }).toList();

              setStateModal(() => sugerencias = filtered);
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 40,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.place, size: 40, color: Colors.blueAccent),
                    const SizedBox(height: 8),
                    const Text(
                      '¿A dónde quieres ir?',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: searchController,
                      autofocus: true,
                      onChanged: buscarUbicaciones,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        hintText: "Buscar dirección...",
                        prefixIcon:
                            const Icon(Icons.search, color: Colors.blueAccent),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(
                              color: Colors.blueAccent, width: 2.0),
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide:
                              const BorderSide(color: Colors.grey, width: 1.0),
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (sugerencias.isNotEmpty)
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: sugerencias.length,
                          itemBuilder: (context, index) {
                            final lugar = sugerencias[index];
                            final nombre = lugar['nombre'];
                            final GeoPoint geopoint = lugar['ubicacion'];

                            return ListTile(
                              leading: const Icon(Icons.location_on,
                                  color: Colors.blue),
                              title: Text(nombre ?? ''),
                              onTap: () {
                                Navigator.pop(
                                  context,
                                  UbicacionResultado(
                                    location: LatLng(
                                        geopoint.latitude, geopoint.longitude),
                                    direccion: nombre,
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      )
                    else if (searchController.text.isNotEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(
                          "No se encontraron resultados",
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: Colores.amarillo,
        title: const Text("Mapa Cliente"),
      ),
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
            ),
        ],
      ),
    );
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
    debugPrint("Error inesperado: $e");
  }

  return [];
}

}

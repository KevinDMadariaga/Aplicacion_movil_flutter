import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_place/google_place.dart';
import 'package:taxi_app/components/boton.dart';
import 'package:taxi_app/components/colores.dart';
import 'package:taxi_app/screens/cliente/recogida_cliente.dart';
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
  String? _solicitudId; // Guardar el ID de la solicitud creada
  bool _mostrarInformacionUbicacion = false;

  @override
  void initState() {
    super.initState();
    _obtenerYCentrarUbicacion();
  }

  Future<void> _obtenerYCentrarUbicacion() async {
    try {
      // Verifica que los servicios de ubicación estén habilitados
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw "Los servicios de ubicación están deshabilitados.";
      }

      // Verifica y solicita permisos de ubicación
      LocationPermission permisos = await Geolocator.checkPermission();
      if (permisos == LocationPermission.denied) {
        permisos = await Geolocator.requestPermission();
      }
      if (permisos == LocationPermission.deniedForever) {
        throw "Permisos de ubicación denegados permanentemente.";
      }

      // Obtén la posición actual con alta precisión
      Position posicion = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      _userLocation = LatLng(posicion.latitude, posicion.longitude);

      // Obtiene la dirección exacta a partir de las coordenadas
      List<Placemark> placemarks =
          await placemarkFromCoordinates(posicion.latitude, posicion.longitude);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        String direccion = "";
        if (place.street != null && place.street!.isNotEmpty) {
          direccion += place.street!;
        }
        if (place.locality != null && place.locality!.isNotEmpty) {
          direccion += ", ${place.locality}";
        }
        if (place.administrativeArea != null &&
            place.administrativeArea!.isNotEmpty) {
          direccion += ", ${place.administrativeArea}";
        }
        if (place.country != null && place.country!.isNotEmpty) {
          direccion += ", ${place.country}";
        }
        _direccionInicial =
            direccion.isNotEmpty ? direccion : "Dirección desconocida";
      } else {
        _direccionInicial = "Dirección desconocida";
      }

      // Guarda la ubicación en Firestore para el usuario autenticado
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint("⚠️ Usuario no autenticado.");
      } else {
        await FirebaseFirestore.instance
            .collection('cliente')
            .doc(user.uid)
            .set(
          {
            'ubicacion': GeoPoint(posicion.latitude, posicion.longitude),
            'ultima_actualizacion': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
        debugPrint("✅ Ubicación guardada en Firestore.");
      }

      // Centra el mapa en la ubicación obtenida
      if (mounted) {
        _mapController.animateCamera(
          CameraUpdate.newLatLngZoom(_userLocation!, 16.0),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al obtener ubicación: $e')),
        );
      }
    }
  }

  void _ajustarVistaMarcadores() {
    if (_userLocation != null && _ultimaUbicacionSeleccionada != null) {
      LatLngBounds bounds = LatLngBounds(
        southwest: LatLng(
          _userLocation!.latitude < _ultimaUbicacionSeleccionada!.latitude
              ? _userLocation!.latitude
              : _ultimaUbicacionSeleccionada!.latitude,
          _userLocation!.longitude < _ultimaUbicacionSeleccionada!.longitude
              ? _userLocation!.longitude
              : _ultimaUbicacionSeleccionada!.longitude,
        ),
        northeast: LatLng(
          _userLocation!.latitude > _ultimaUbicacionSeleccionada!.latitude
              ? _userLocation!.latitude
              : _ultimaUbicacionSeleccionada!.latitude,
          _userLocation!.longitude > _ultimaUbicacionSeleccionada!.longitude
              ? _userLocation!.longitude
              : _ultimaUbicacionSeleccionada!.longitude,
        ),
      );

      _mapController.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));
    }
  }

  Future<void> _mostrarCuadroBusqueda() async {
    List<AutocompletePrediction> predictions = [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            // Función para buscar ubicaciones
            void buscarUbicaciones(String input) async {
              if (input.isEmpty) {
                setModalState(() => predictions = []);
                return;
              }

              try {
                final response = await _googlePlace.autocomplete.get(
                  input,
                  location: const LatLon(8.2595534, -73.353469),
                  radius: 10000,
                  strictbounds: true,
                  components: [Component("country", "co")],
                );

                setModalState(() => predictions = response?.predictions ?? []);
              } catch (e) {
                debugPrint("Error al buscar ubicaciones: $e");
              }
            }

            // Función para seleccionar una ubicación
            // Función para seleccionar una ubicación
            void seleccionarUbicacion(
                String placeId, String descripcionSeleccionada) async {
              try {
                final details = await _googlePlace.details.get(placeId);
                if (details?.result?.geometry?.location == null) return;

                final location = details!.result!.geometry!.location!;
                LatLng nuevaPosicion = LatLng(location.lat!, location.lng!);
                String direccionCompleta =
                    details.result!.formattedAddress ?? "Dirección desconocida";

                // Extraer barrio y código postal
                String barrio = "Barrio desconocido";
                String postalCode = "Sin código postal";

                details.result!.addressComponents?.forEach((component) {
                  if (component.types!.contains("sublocality") ||
                      component.types!.contains("neighborhood")) {
                    barrio = component.longName!;
                  }
                  if (component.types!.contains("postal_code")) {
                    postalCode = component.longName!;
                  }
                });

                // Actualizar estado con la nueva ubicación
                setState(() {
                  _ultimaDireccionSeleccionada = descripcionSeleccionada;
                  _ultimaUbicacionSeleccionada = nuevaPosicion;
                  _mostrarInformacionUbicacion = true;
                  _mostrarBotonTaxi = false;
                  _searchController.clear();

                  _markers
                    ..removeWhere(
                        (m) => m.markerId.value == "ubicacion_seleccionada")
                    ..add(Marker(
                      markerId: const MarkerId("ubicacion_seleccionada"),
                      position: nuevaPosicion,
                      infoWindow: InfoWindow(
                        title: barrio,
                        snippet:
                            "$direccionCompleta\nCódigo Postal: $postalCode",
                      ),
                    ));

                  _polylines
                    ..clear()
                    ..add(Polyline(
                      polylineId: const PolylineId('ruta'),
                      points: [_userLocation!, nuevaPosicion],
                      color: const Color.fromARGB(255, 0, 0, 0),
                      width: 4,
                    ));

                  _ajustarVistaMarcadores();
                });

                Navigator.pop(context);
              } catch (e) {
                debugPrint("Error al seleccionar ubicación: $e");
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 16.0,
                right: 16.0,
                top: 16.0,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16.0,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Buscar Ubicación',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _searchController,
                    onChanged: buscarUbicaciones,
                    decoration: InputDecoration(
                      hintText: "Buscar ubicación...",
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (predictions.isNotEmpty)
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.4,
                      child: ListView.builder(
                        itemCount: predictions.length,
                        itemBuilder: (context, index) {
                          final prediction = predictions[index];
                          return ListTile(
                            leading: const Icon(Icons.location_on,
                                color: Colors.blue),
                            title: Text(prediction.description ?? ""),
                            onTap: () => seleccionarUbicacion(
                              prediction.placeId!,
                              prediction.description ?? "Dirección desconocida",
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 10),
                  CustomButton(
                    text: 'Cancelar',
                    onPressed: () async {
                      try {
                        if (_solicitudId != null) {
                          await FirebaseFirestore.instance
                              .collection('solicitud')
                              .doc(_solicitudId)
                              .update({'estado': 'cancelada'});

                          setState(() {
                            _solicitudId = null;
                            _mostrarInformacionUbicacion = false;
                            _mostrarBotonTaxi = true;
                            _markers.removeWhere((m) =>
                                m.markerId.value == "ubicacion_seleccionada");
                            _polylines.clear();

                            if (_userLocation != null) {
                              _mapController.animateCamera(
                                CameraUpdate.newLatLngZoom(
                                    _userLocation!, 15.0),
                              );
                            }
                          });

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content:
                                    Text('Solicitud cancelada correctamente')),
                          );
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content:
                                  Text('Error al cancelar la solicitud: $e')),
                        );
                      }

                      Navigator.pop(context);
                    },
                    width: 130,
                    height: 50,
                    fontSize: 16,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> enviarSolicitud(BuildContext context) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Usuario no autenticado')),
        );
        return;
      }

      if (_userLocation == null || _ultimaUbicacionSeleccionada == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Información de ubicación incompleta')),
        );
        return;
      }

      // Crear una nueva solicitud en Firestore con el nombre de la ubicación seleccionada
      DocumentReference solicitudRef =
          await FirebaseFirestore.instance.collection('solicitud').add({
        'clienteId': user.uid,
        'ubicacion_inicial':
            GeoPoint(_userLocation!.latitude, _userLocation!.longitude),
        'ubicacion_seleccionada': GeoPoint(
          _ultimaUbicacionSeleccionada!.latitude,
          _ultimaUbicacionSeleccionada!.longitude,
        ),
        'direccion_seleccionada':
            _ultimaDireccionSeleccionada, // Nuevo campo agregado
        'estado': 'pendiente',
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Actualizar UI
      setState(() {
        _solicitudId = solicitudRef.id;
        _mostrarInformacionUbicacion = false;
      });

      // Enviar notificación a los conductores cercanos
      await _enviarNotificacionConductores(solicitudRef.id);

      // Escuchar cambios en la solicitud en tiempo real
      _escucharCambiosSolicitud(_solicitudId!);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al enviar la solicitud: $e')),
      );
    }
  }

  void _escucharCambiosSolicitud(String solicitudId) {
    FirebaseFirestore.instance
        .collection('solicitud')
        .doc(solicitudId)
        .snapshots()
        .listen((doc) {
      if (doc.exists) {
        String estado = doc['estado'] ?? '';

        if (estado == 'cancelada') {
          FirebaseFirestore.instance
              .collection('solicitud')
              .doc(solicitudId)
              .delete();

          if (mounted) {
            setState(() {
              _solicitudId = null;
              _mostrarInformacionUbicacion = false;
              _mostrarBotonTaxi = true;
              _markers.removeWhere(
                  (m) => m.markerId.value == "ubicacion_seleccionada");
              _polylines.clear();
            });

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Solicitud cancelada y eliminada.')),
            );
          }
        }

        if (estado == 'aceptada') {
          GeoPoint ubicacionInicial = doc['ubicacion_inicial'];
          GeoPoint ubicacionDestino = doc['ubicacion_seleccionada'];

          if (mounted) {
            setState(() {
              _mostrarInformacionUbicacion = true;
              _markers.add(Marker(
                markerId: const MarkerId("ubicacion_seleccionada"),
                position: LatLng(
                    ubicacionDestino.latitude, ubicacionDestino.longitude),
                infoWindow: const InfoWindow(title: "Destino seleccionado"),
              ));

              _polylines.clear();
              _polylines.add(Polyline(
                polylineId: const PolylineId('ruta'),
                points: [
                  LatLng(ubicacionInicial.latitude, ubicacionInicial.longitude),
                  LatLng(ubicacionDestino.latitude, ubicacionDestino.longitude)
                ],
                color: const Color.fromARGB(255, 229, 243, 33),
                width: 4,
              ));
            });
          }
        }
      }
    });
  }

  Future<void> _enviarNotificacionPush(String token, String solicitudId) async {
    try {
      await FirebaseFirestore.instance.collection('notificaciones').add({
        'token': token,
        'titulo': 'Nueva solicitud de viaje',
        'mensaje':
            'Un cliente ha solicitado un viaje. Acepta la solicitud ahora.',
        'solicitudId': solicitudId,
        'timestamp': FieldValue.serverTimestamp(),
      });

      debugPrint("✅ Notificación enviada al conductor con token: $token");
    } catch (e) {
      debugPrint("❌ Error al enviar la notificación push: $e");
    }
  }

  Future<void> _enviarNotificacionConductores(String solicitudId) async {
    try {
      QuerySnapshot conductoresSnapshot = await FirebaseFirestore.instance
          .collection('usuarios')
          .where('tipo', isEqualTo: 'conductor')
          .get();

      List<String> tokens = conductoresSnapshot.docs
          .map((doc) => doc['token'] as String?)
          .where((token) => token != null)
          .cast<String>()
          .toList();

      if (tokens.isEmpty) {
        debugPrint(
            "No hay conductores disponibles para recibir la notificación.");
        return;
      }

      for (String token in tokens) {
        await _enviarNotificacionPush(token, solicitudId);
      }
    } catch (e) {
      debugPrint("Error al enviar notificación a conductores: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      resizeToAvoidBottomInset: false, // Evita que el teclado afecte el mapa
      appBar: AppBar(
        backgroundColor: Colores.amarillo,
        title: const Text("Mapa Cliente"),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            DrawerHeader(
              decoration: BoxDecoration(
                color: Colores.amarillo,
              ),
              child: Text(
                'Bienvenido, ${user?.email ?? 'Usuario'}',
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Cerrar Sesión'),
              onTap: () async {
                await FirebaseAuth.instance.signOut();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const home()),
                );
              },
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _userLocation ?? const LatLng(8.2595534, -73.353469),
              zoom: 15.0,
            ),
            onMapCreated: (GoogleMapController controller) {
              _mapController = controller;
            },
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: true,
          ),
          if (_mostrarInformacionUbicacion)
            Positioned(
              bottom: 20,
              left: 16,
              right: 16,
              child: Card(
                color: Colors.white,
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.0),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Ubicación Inicial:",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(_direccionInicial),
                      const SizedBox(height: 10),
                      Text(
                        "Ubicación Seleccionada:",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        _ultimaDireccionSeleccionada.isNotEmpty
                            ? _ultimaDireccionSeleccionada
                            : "No se ha seleccionado una ubicación",
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          CustomButton(
                            text: 'Cancelar',
                            onPressed: () async {
                              try {
                                if (_solicitudId != null) {
                                  debugPrint(
                                      "Cancelando solicitud con ID: $_solicitudId");

                                  // 🔹 Verificar si la solicitud existe antes de actualizar
                                  final solicitudRef = FirebaseFirestore
                                      .instance
                                      .collection('solicitud')
                                      .doc(_solicitudId);

                                  final solicitudSnapshot =
                                      await solicitudRef.get();
                                  if (solicitudSnapshot.exists) {
                                    await solicitudRef
                                        .update({'estado': 'cancelada'});

                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              'Solicitud cancelada correctamente')),
                                    );
                                  } else {
                                    debugPrint(
                                        "La solicitud con ID $_solicitudId no existe.");
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              'Error: La solicitud no existe')),
                                    );
                                  }
                                } else {
                                  debugPrint("Error: _solicitudId es null");
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'No hay solicitud activa para cancelar')),
                                  );
                                }

                                // 🔹 Limpia la UI y regresa al mapa principal
                                setState(() {
                                  _solicitudId = null;
                                  _mostrarInformacionUbicacion = false;
                                  _mostrarBotonTaxi = true;

                                  // Eliminar el marcador de la ubicación seleccionada
                                  _markers.removeWhere(
                                    (marker) =>
                                        marker.markerId.value ==
                                        "ubicacion_seleccionada",
                                  );

                                  // Limpiar las polilíneas
                                  _polylines.clear();

                                  // Recentrar el mapa en la ubicación inicial del usuario
                                  if (_userLocation != null) {
                                    _mapController.animateCamera(
                                      CameraUpdate.newLatLngZoom(
                                          _userLocation!, 15.0),
                                    );
                                  }
                                });

                                // 🔹 Cierra el modal si está abierto
                                if (Navigator.canPop(context)) {
                                  Navigator.pop(context);
                                }
                              } catch (e) {
                                debugPrint(
                                    "Error al cancelar la solicitud: $e");
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(
                                          'Error al cancelar la solicitud: $e')),
                                );
                              }
                            },
                            width: 130,
                            height: 50,
                            fontSize: 16,
                          ),
                          CustomButton(
                            text: 'Aceptar',
                            onPressed: () async {
                              try {
                                // 🔹 Mostrar Loader mientras se busca un conductor
                                showDialog(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (BuildContext context) {
                                    return AlertDialog(
                                      content: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const CircularProgressIndicator(),
                                          const SizedBox(height: 15),
                                          const Text("Buscando conductor..."),
                                          const SizedBox(height: 10),
                                          CustomButton(
                                            text: "Cancelar",
                                            onPressed: () async {
                                              if (_solicitudId != null) {
                                                await FirebaseFirestore.instance
                                                    .collection('solicitud')
                                                    .doc(_solicitudId)
                                                    .update({
                                                  'estado': 'cancelada'
                                                });
                                              }

                                              Navigator.of(context,
                                                      rootNavigator: true)
                                                  .pop();

                                              setState(() {
                                                _solicitudId = null;
                                                _mostrarInformacionUbicacion =
                                                    false;
                                                _mostrarBotonTaxi = true;
                                                _markers.removeWhere((marker) =>
                                                    marker.markerId.value ==
                                                    "ubicacion_seleccionada");
                                                _polylines.clear();

                                                if (_userLocation != null) {
                                                  _mapController.animateCamera(
                                                    CameraUpdate.newLatLngZoom(
                                                        _userLocation!, 15.0),
                                                  );
                                                }
                                              });
                                            },
                                            width: 130,
                                            height: 50,
                                            fontSize: 16,
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                );

                                // 🔹 Enviar la solicitud a Firestore
                                await enviarSolicitud(context);

                                // 🔹 Escuchar en tiempo real si la solicitud es aceptada
                                FirebaseFirestore.instance
                                    .collection('solicitud')
                                    .doc(_solicitudId)
                                    .snapshots()
                                    .listen((doc) {
                                  if (doc.exists &&
                                      doc['estado'] == 'aceptada') {
                                    Navigator.of(context, rootNavigator: true)
                                        .pop(); // 🔹 Cerrar el Loader
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ClienteRecogida(
                                          solicitudId: _solicitudId!,
                                          conductorId: doc['conductorId'],
                                          ubicacionInicial: LatLng(
                                            doc['ubicacion_inicial'].latitude,
                                            doc['ubicacion_inicial'].longitude,
                                          ),
                                          ubicacionDestino: LatLng(
                                            doc['ubicacion_seleccionada']
                                                .latitude,
                                            doc['ubicacion_seleccionada']
                                                .longitude,
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                });
                              } catch (e) {
                                Navigator.of(context, rootNavigator: true)
                                    .pop(); // 🔹 Cerrar el loader en caso de error
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content:
                                          Text('Error al solicitar viaje: $e')),
                                );
                              }
                            },
                            width: 130,
                            height: 50,
                            fontSize: 16,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (_mostrarBotonTaxi)
            Positioned(
              bottom: 80,
              left: MediaQuery.of(context).size.width * 0.3,
              child: CustomButton(
                text: 'Buscar Taxi',
                onPressed: _mostrarCuadroBusqueda,
                width: 160, // Ancho del botón
                height: 50, // Alto del botón
                fontSize: 16, // Tamaño de fuente del texto
              ),
            )
        ],
      ),
    );
  }
}

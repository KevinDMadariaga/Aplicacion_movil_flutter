import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_place/google_place.dart';
import 'package:taxi_app/components/boton.dart';
import 'package:taxi_app/components/colores.dart';
import 'package:http/http.dart' as http;
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
  bool _mostrandoBusquedaConductor = false;

  @override
  void initState() {
    super.initState();
    _centrarUbicacionInicial();
  }

  Future<void> _centrarUbicacionInicial() async {
    try {
      bool servicioHabilitado = await Geolocator.isLocationServiceEnabled();
      if (!servicioHabilitado) {
        throw "Los servicios de ubicación están deshabilitados.";
      }

      LocationPermission permisos = await Geolocator.checkPermission();
      if (permisos == LocationPermission.denied) {
        permisos = await Geolocator.requestPermission();
        if (permisos == LocationPermission.denied) {
          throw "Los permisos de ubicación fueron denegados.";
        }
      }

      if (permisos == LocationPermission.deniedForever) {
        throw "Los permisos de ubicación están denegados permanentemente.";
      }

      Position posicion = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      _userLocation = LatLng(posicion.latitude, posicion.longitude);

      List<Placemark> placemarks = await placemarkFromCoordinates(
        posicion.latitude,
        posicion.longitude,
      );

      if (placemarks.isNotEmpty) {
        final Placemark place = placemarks.first;
        _direccionInicial =
            "${place.street}, ${place.locality}, ${place.administrativeArea}";
      }

      setState(() {});

      _mapController.animateCamera(
        CameraUpdate.newLatLngZoom(_userLocation!, 15.0),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al obtener ubicación: $e')),
      );
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

      // Ajustar límites con un desplazamiento hacia abajo para que los marcadores estén arriba
      final double latAdjustment =
          (bounds.northeast.latitude - bounds.southwest.latitude) * 0.3;

      LatLngBounds adjustedBounds = LatLngBounds(
        southwest: LatLng(bounds.southwest.latitude - latAdjustment,
            bounds.southwest.longitude),
        northeast:
            LatLng(bounds.northeast.latitude, bounds.northeast.longitude),
      );

      // Mover la cámara para mostrar los puntos ajustados
      _mapController
          .animateCamera(CameraUpdate.newLatLngBounds(adjustedBounds, 100));
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
            void buscarUbicaciones(String input) async {
              if (input.isEmpty) {
                setModalState(() {
                  predictions = [];
                });
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

                if (response != null && response.predictions != null) {
                  setModalState(() {
                    predictions = response.predictions!;
                  });
                }
              } catch (e) {
                debugPrint("Error al buscar ubicaciones: $e");
              }
            }

            void seleccionarUbicacion(String placeId) async {
              try {
                final details = await _googlePlace.details.get(placeId);
                if (details != null && details.result != null) {
                  final location = details.result!.geometry!.location!;
                  LatLng nuevaPosicion = LatLng(location.lat!, location.lng!);

                  // Usar formatted_address para obtener la dirección completa
                  _ultimaDireccionSeleccionada =
                      details.result!.formattedAddress ??
                          "Dirección desconocida";
                  _ultimaUbicacionSeleccionada = nuevaPosicion;

                  setState(() {
                    _mostrarInformacionUbicacion = true;
                    _mostrarBotonTaxi = false;
                    _searchController.clear();

                    // Eliminar todos los marcadores previos excepto el marcador inicial
                    _markers.removeWhere((marker) =>
                        marker.markerId.value == "ubicacion_seleccionada");

                    // Agregar un nuevo marcador para la ubicación seleccionada
                    _markers.add(
                      Marker(
                        markerId: const MarkerId("ubicacion_seleccionada"),
                        position: nuevaPosicion,
                        infoWindow: InfoWindow(
                          title: details.result!.formattedAddress ??
                              "Ubicación Seleccionada",
                        ),
                      ),
                    );

                    // Dibujar polilínea entre la ubicación inicial y la seleccionada
                    _polylines.clear();
                    _polylines.add(
                      Polyline(
                        polylineId: const PolylineId('route'),
                        points: [_userLocation!, nuevaPosicion],
                        color: Colors.blue,
                        width: 4,
                      ),
                    );

                    // Ajustar la vista para mostrar ambos puntos
                    _ajustarVistaMarcadores();
                  });

                  Navigator.pop(context);
                }
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
                    onChanged: (input) {
                      buscarUbicaciones(input);
                    },
                    decoration: InputDecoration(
                      hintText: "Buscar ubicación...",
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
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
                            onTap: () {
                              seleccionarUbicacion(prediction.placeId!);
                            },
                          );
                        },
                      ),
                    )
                  else
                    const SizedBox(height: 10),
                  CustomButton(
                    text: 'Cancelar',
                    onPressed: () async {
                      try {
                        if (_solicitudId != null) {
                          // 🔹 Cierra el showModalBottomSheet si está abierto
                          if (Navigator.canPop(context)) {
                            Navigator.pop(context);
                          }

                          // 🔹 Cambiar el estado de la solicitud a "cancelada"
                          await FirebaseFirestore.instance
                              .collection('solicitud')
                              .doc(_solicitudId)
                              .update({'estado': 'cancelada'});

                          // 🔹 Limpia la interfaz en la app
                          setState(() {
                            _solicitudId = null;
                            _mostrarInformacionUbicacion = false;
                            _mostrarBotonTaxi = true;

                            // Eliminar el marcador de la ubicación seleccionada
                            _markers.removeWhere((marker) =>
                                marker.markerId.value ==
                                "Ubicación Seleccionada");

                            // Limpiar las polilíneas
                            _polylines.clear();

                            // Recentrar en la ubicación inicial
                            if (_userLocation != null) {
                              _mapController.animateCamera(
                                CameraUpdate.newLatLngZoom(
                                    _userLocation!, 15.0),
                              );
                            }
                          });

                          // 🔹 Notificar al usuario que la solicitud fue cancelada
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content:
                                    Text('Solicitud cancelada correctamente')),
                          );
                        }
                      } catch (e) {
                        // Manejo de errores en caso de fallo
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content:
                                  Text('Error al cancelar la solicitud: $e')),
                        );
                      }
                    },
                    width: 115, // Ancho del botón
                    height: 50, // Alto del botón
                    fontSize: 16, // Tamaño de fuente del texto
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> enviarSolicitud() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null ||
          _userLocation == null ||
          _ultimaUbicacionSeleccionada == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Información de ubicación incompleta')),
        );
        return;
      }

      DocumentReference solicitudRef =
          await FirebaseFirestore.instance.collection('solicitud').add({
        'clienteId': user.uid,
        'ubicacion_inicial':
            GeoPoint(_userLocation!.latitude, _userLocation!.longitude),
        'ubicacion_seleccionada': GeoPoint(
          _ultimaUbicacionSeleccionada!.latitude,
          _ultimaUbicacionSeleccionada!.longitude,
        ),
        'estado': 'pendiente',
        'timestamp': FieldValue.serverTimestamp(),
      });

      setState(() {
        _solicitudId = solicitudRef.id;
        _mostrarInformacionUbicacion = false;
        _mostrandoBusquedaConductor = true;
      });

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

        if (estado == 'aceptada') {
          setState(() {
            _mostrandoBusquedaConductor = false;
          });

          // 🔹 Aquí puedes agregar la navegación a otra pantalla cuando sea aceptada
        }
      }
    });
  }

  Future<void> _cancelarSolicitud() async {
    try {
      if (_solicitudId != null) {
        await FirebaseFirestore.instance
            .collection('solicitud')
            .doc(_solicitudId)
            .update({'estado': 'cancelada'});

        setState(() {
          _mostrandoBusquedaConductor = false;
          _solicitudId = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Solicitud cancelada')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cancelar: $e')),
      );
    }
  }

  Future<void> _enviarNotificacionATodosLosConductores(
      String solicitudId) async {
    try {
      QuerySnapshot conductores = await FirebaseFirestore.instance
          .collection('conductores')
          .where('disponible', isEqualTo: true)
          .get();

      for (var doc in conductores.docs) {
        String token = doc['fcmToken'] ?? '';
        if (token.isNotEmpty) {
          await _enviarNotificacion(token, solicitudId);
        }
      }
    } catch (e) {
      print("Error enviando notificación: $e");
    }
  }

  Future<void> _enviarNotificacion(String token, String solicitudId) async {
    const String serverKey =
        'BAxoHsuKFFIekEnr0FGYnxFo2FII3DUqfx64EKxb_YR5YHrsjDKILTDkh5il8d78A83R4rbxb-yUwOR4_MssNYI'; // 🔥 Reemplázala con tu clave real

    final body = {
      "to": token,
      "notification": {
        "title": "Nueva solicitud de taxi",
        "body": "Un cliente ha solicitado un taxi. Acepta la solicitud.",
      },
      "data": {
        "solicitudId": solicitudId,
      }
    };

    final response = await http.post(
      Uri.parse("https://fcm.googleapis.com/fcm/send"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "key=$serverKey",
      },
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      print("Notificación enviada con éxito.");
    } else {
      print("Error al enviar la notificación: ${response.body}");
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
                      Text(_ultimaDireccionSeleccionada),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          CustomButton(
                            text: 'Cancelar',
                            onPressed: () {
                              setState(() {
                                // Ocultar la información de ubicación seleccionada
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

                                // Recentrar en la ubicación inicial
                                if (_userLocation != null) {
                                  _mapController.animateCamera(
                                    CameraUpdate.newLatLngZoom(
                                        _userLocation!, 15.0),
                                  );
                                }
                              });
                            },
                            width: 115, // Ancho del botón
                            height: 50, // Alto del botón
                            fontSize: 16, // Tamaño de fuente del texto
                          ),
                          CustomButton(
                            text: 'Aceptar',
                            onPressed: () async {
                              try {
                                // Obtener ID del cliente actual
                                final user = FirebaseAuth.instance.currentUser;

                                if (user != null &&
                                    _userLocation != null &&
                                    _ultimaUbicacionSeleccionada != null) {
                                  // Crear un punto geográfico en Firestore con GeoPoint
                                  DocumentReference solicitudRef =
                                      await FirebaseFirestore.instance
                                          .collection('solicitud')
                                          .add({
                                    'clienteId': user.uid,
                                    'ubicacion_inicial': GeoPoint(
                                        _userLocation!.latitude,
                                        _userLocation!
                                            .longitude), // 🔹 Guardado como punto geográfico
                                    'ubicacion_seleccionada': GeoPoint(
                                        _ultimaUbicacionSeleccionada!.latitude,
                                        _ultimaUbicacionSeleccionada!
                                            .longitude), // 🔹 Guardado como punto geográfico
                                    'estado': 'pendiente',
                                    'timestamp': FieldValue.serverTimestamp(),
                                  });

                                  // Obtener ID de la solicitud para escuchar cambios
                                  String solicitudId = solicitudRef.id;

                                  // Mostrar mensaje al usuario
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'Solicitud enviada, esperando conductor...')),
                                  );

                                  // ✅ Escuchar cambios en Firestore (esperar que la solicitud sea aceptada antes de cambiar de pantalla)
                                  // _escucharCambiosSolicitud(solicitudId);

                                  // ✅ Enviar notificación a conductores
                                  //  _enviarNotificacionATodosLosConductores(solicitudId);
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'Error: Ubicación no disponible')),
                                  );
                                }
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(
                                          'Error al enviar la solicitud: $e')),
                                );
                              }
                            },
                            width: 115,
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
              left: MediaQuery.of(context).size.width * 0.4,
              child: CustomButton(
                text: 'Taxi',
                onPressed: _mostrarCuadroBusqueda,
                width: 89, // Ancho del botón
                height: 50, // Alto del botón
                fontSize: 16, // Tamaño de fuente del texto
              ),
            )
        ],
      ),
    );
  }
}

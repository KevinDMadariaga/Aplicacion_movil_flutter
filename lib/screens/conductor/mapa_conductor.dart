import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:taxi_app/components/colores.dart';
import 'package:taxi_app/screens/conductor/recogida_conductor.dart';
import 'package:taxi_app/screens/home.dart';
import 'package:geocoding/geocoding.dart';

class MapaConductor extends StatefulWidget {
  const MapaConductor({super.key});

  @override
  State<MapaConductor> createState() => _MapaConductorState();
}

class _MapaConductorState extends State<MapaConductor> {
  late GoogleMapController _mapController;
  final Set<Marker> _markers = {};
  User? _conductor;
  LatLng? _currentPosition;
  String? _solicitudId;
  Stream<DocumentSnapshot>? _solicitudStream;
  StreamSubscription<Position>? _positionStreamSubscription;

  @override
  void initState() {
    super.initState();
    _conductor = FirebaseAuth.instance.currentUser;
    _configurarNotificaciones();
    _iniciarSeguimientoUbicacion(); // Inicia el seguimiento de ubicación en tiempo real
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _centrarUbicacionActual();
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    super.dispose();
  }

  Future<void> _centrarUbicacionActual() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw "Los servicios de ubicación están deshabilitados.";
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw "Los permisos de ubicación fueron denegados.";
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw "Los permisos de ubicación están denegados permanentemente.";
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (mounted) {
        setState(() {
          _currentPosition = LatLng(position.latitude, position.longitude);
        });

        _mapController.animateCamera(
          CameraUpdate.newLatLngZoom(_currentPosition!, 15.0),
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

  /// Método para iniciar el seguimiento en tiempo real de la ubicación del conductor,
  /// actualizando la posición en Firestore y centrando el mapa.
  void _iniciarSeguimientoUbicacion() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw "Los servicios de ubicación están deshabilitados.";
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          throw "Permiso de ubicación denegado.";
        }
      }

      _positionStreamSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10, // Actualiza cada 10 metros de cambio
        ),
      ).listen((Position position) {
        if (mounted) {
          setState(() {
            _currentPosition = LatLng(position.latitude, position.longitude);
          });
          // Actualiza la ubicación del conductor en Firestore
          FirebaseFirestore.instance
              .collection('conductor')
              .doc(_conductor!.uid)
              .update({
            'ubicacion': GeoPoint(position.latitude, position.longitude)
          });
          // Centra el mapa en la nueva ubicación
          _mapController
              .animateCamera(CameraUpdate.newLatLng(_currentPosition!));
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al iniciar seguimiento: $e')),
        );
      }
    }
  }

  void _configurarNotificaciones() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.data.containsKey('solicitudId')) {
        String solicitudId = message.data['solicitudId'];

        // Verificar si la app está en primer plano
        if (mounted) {
          if (_solicitudId != solicitudId) {
            _solicitudId = solicitudId;
            _escucharSolicitudDesdeFirestore(solicitudId);
          }
        } else {
          // Si la app está en segundo plano o cerrada, mostrar notificación push
          _mostrarNotificacionLocal(
              message.notification?.title ?? "Nueva Solicitud",
              message.notification?.body ??
                  "Un cliente ha solicitado un taxi.");
        }
      }
    });

    // Manejar cuando la notificación es pulsada y la app está cerrada
    FirebaseMessaging.instance
        .getInitialMessage()
        .then((RemoteMessage? message) {
      if (message != null && message.data.containsKey('solicitudId')) {
        String solicitudId = message.data['solicitudId'];
        _solicitudId = solicitudId;
        _escucharSolicitudDesdeFirestore(solicitudId);
      }
    });

    // Escuchar cuando la notificación es tocada con la app en segundo plano
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (message.data.containsKey('solicitudId')) {
        String solicitudId = message.data['solicitudId'];
        _solicitudId = solicitudId;
        _escucharSolicitudDesdeFirestore(solicitudId);
      }
    });

    // Solo escuchar solicitudes en tiempo real cuando la app está abierta
    if (mounted) {
      FirebaseFirestore.instance
          .collection('solicitud')
          .where('estado', isEqualTo: 'pendiente')
          .snapshots()
          .listen((snapshot) {
        for (var doc in snapshot.docs) {
          if (_solicitudId != doc.id) {
            _solicitudId = doc.id;
            _escucharSolicitudDesdeFirestore(doc.id);
          }
        }
      });
    }
  }

  /// Método para mostrar una notificación local en la barra de estado
  void _mostrarNotificacionLocal(String titulo, String mensaje) async {
    // Aquí debes usar un paquete de notificaciones locales como flutter_local_notifications
    print("🔔 Notificación Local: $titulo - $mensaje");
    // Implementar con flutter_local_notifications si es necesario
  }

  void _escucharSolicitudDesdeFirestore(String solicitudId) {
    setState(() {
      _solicitudStream = FirebaseFirestore.instance
          .collection('solicitud')
          .doc(solicitudId)
          .snapshots();
    });
  }

  /// Método para obtener el nombre del cliente a partir del ID
  Future<String> _obtenerNombreCliente(String clienteId) async {
    try {
      if (clienteId.isEmpty) return 'Desconocido';

      DocumentSnapshot clienteDoc = await FirebaseFirestore.instance
          .collection('cliente') // Asegúrate de que la colección sea correcta
          .doc(clienteId)
          .get();

      if (clienteDoc.exists) {
        return clienteDoc['nombre'] ?? 'Desconocido';
      } else {
        return 'Desconocido';
      }
    } catch (e) {
      print("Error obteniendo el nombre del cliente: $e");
      return 'Desconocido';
    }
  }

  Future<String> _obtenerDireccion(GeoPoint ubicacion) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
          ubicacion.latitude, ubicacion.longitude);

      if (placemarks.isNotEmpty) {
        final Placemark place = placemarks.first;

        // Construir una dirección más detallada
        String address = "";
        if (place.street != null) address += place.street!;
        if (place.subLocality != null) address += ", ${place.subLocality}";
        if (place.locality != null) address += ", ${place.locality}";
        if (place.administrativeArea != null)
          address += ", ${place.administrativeArea}";
        if (place.country != null) address += ", ${place.country}";

        return address.isNotEmpty ? address : "Dirección desconocida";
      } else {
        return "Dirección desconocida";
      }
    } catch (e) {
      print("Error obteniendo dirección: $e");
      return "Dirección desconocida";
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

        // Si la solicitud es aceptada, navegar a la pantalla ConductorRecogida
        if (estado == 'aceptada') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => ConductorRecogida(
                clienteId: doc['clienteId'],
                ubicacionInicial: doc['ubicacion_inicial'],
                ubicacionDestino: doc['ubicacion_seleccionada'],
              ),
            ),
          );
        }
        // Si la solicitud es cancelada, dejar de mostrarla
        if (estado == 'cancelada') {
          setState(() {
            _solicitudStream = null;
            _solicitudId = null;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('La solicitud fue cancelada por el cliente.')),
          );
        }
      }
    });
  }

  Future<void> _aceptarSolicitud() async {
    if (_conductor == null || _solicitudId == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('solicitud')
          .doc(_solicitudId)
          .update({
        'estado': 'aceptada',
        'conductorId': _conductor!.uid,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solicitud aceptada con éxito')),
      );

      // Comenzar a escuchar cambios en la solicitud después de aceptarla
      _escucharCambiosSolicitud(_solicitudId!);

      if (mounted) {
        setState(() {
          _solicitudId = null;
          _solicitudStream = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al aceptar la solicitud: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colores.amarillo,
        title: const Text("Mapa Conductor"),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _centrarUbicacionActual,
          ),
        ],
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
                'Bienvenido, ${user?.email ?? 'Conductor'}',
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
                if (mounted) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const home()),
                  );
                }
              },
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentPosition ?? const LatLng(8.2351448, -73.3501841),
              zoom: 15.0,
            ),
            onMapCreated: (GoogleMapController controller) {
              _mapController = controller;
              _centrarUbicacionActual();
            },
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
          ),
          if (_solicitudStream != null)
            StreamBuilder<DocumentSnapshot>(
              stream: _solicitudStream,
              builder: (context, snapshot) {
                if (!snapshot.hasData || !snapshot.data!.exists) {
                  return const SizedBox.shrink();
                }

                var solicitud = snapshot.data!.data() as Map<String, dynamic>;
                GeoPoint ubicacionInicial = solicitud['ubicacion_inicial'];
                // Se utiliza directamente el campo "direccion_seleccionada" del documento
                String direccionSeleccionada =
                    solicitud['direccion_seleccionada'] ??
                        "Dirección no disponible";
                String clienteId = solicitud['clienteId'];

                return FutureBuilder<List<String>>(
                  future: Future.wait([
                    _obtenerNombreCliente(clienteId),
                    _obtenerDireccion(ubicacionInicial),
                    Future.value(direccionSeleccionada),
                  ]),
                  builder: (context, AsyncSnapshot<List<String>> snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    String nombreCliente = snapshot.data![0];
                    String direccionInicial = snapshot.data![1];
                    String direccionDestino = snapshot.data![2];

                    return Positioned(
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
                              const Text(
                                "🚖 Nueva Solicitud Recibida",
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              const Divider(),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.person, color: Colors.blue),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      "Cliente: $nombreCliente",
                                      style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.location_on,
                                      color: Colors.red),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      "🛤 Origen: $direccionInicial",
                                      style: const TextStyle(fontSize: 15),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.flag, color: Colors.green),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      "📍 Destino: $direccionDestino",
                                      style: const TextStyle(fontSize: 15),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 20, vertical: 12),
                                    ),
                                    icon: const Icon(Icons.cancel,
                                        color: Colors.white),
                                    onPressed: () {
                                      setState(() {
                                        _solicitudStream = null;
                                      });
                                    },
                                    label: const Text(
                                      "Rechazar",
                                      style: TextStyle(
                                          fontSize: 16, color: Colors.white),
                                    ),
                                  ),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 20, vertical: 12),
                                    ),
                                    icon: const Icon(Icons.check_circle,
                                        color: Colors.white),
                                    onPressed: _aceptarSolicitud,
                                    label: const Text(
                                      "Aceptar",
                                      style: TextStyle(
                                          fontSize: 16, color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
        ],
      ),
    );
  }
}

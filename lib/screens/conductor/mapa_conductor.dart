import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:taxi_app/components/boton.dart';
import 'package:taxi_app/components/colores.dart';
import 'package:taxi_app/controllers/conductor_controller.dart';
import 'package:taxi_app/screens/conductor/historial_viajes_conductor.dart';
import 'package:taxi_app/screens/conductor/ruta_cliente_conductor.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:taxi_app/screens/home.dart';
import 'package:permission_handler/permission_handler.dart';

class MapaConductor extends StatefulWidget {
  const MapaConductor({super.key});

  @override
  State<MapaConductor> createState() => _MapaConductorState();
}

class _MapaConductorState extends State<MapaConductor> {
  MapaConductorController? controller;
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  Stream<DocumentSnapshot>? _solicitudStream;
  bool? conectadoLocal; // Nueva variable local para manejar estado del botón

  @override
  void initState() {
    super.initState();
    _solicitarPermisosUbicacion().then((granted) {
      if (granted) {
        _inicializarController();
      } else {
        _mostrarDialogoPermisoDenegado();
      }
    });
  }

  void _inicializarController() async {
    controller = MapaConductorController()
      ..configurarNotificaciones()
      ..guardarTokenFCM()
      ..iniciarSeguimientoUbicacion((pos) {
        _mapController?.animateCamera(CameraUpdate.newLatLng(pos));
      });

    await controller!.recuperarEstadoConductor();
    setState(() {
      conectadoLocal = controller!.conectado;
    });

    controller!.onNuevaSolicitud = (id) {
      setState(() {
        _solicitudStream = FirebaseFirestore.instance
            .collection('solicitud')
            .doc(id)
            .snapshots();
      });
    };

    controller!.onSolicitudCancelada = () {
      setState(() => _solicitudStream = null);
    };

    controller!.onSolicitudAceptada = (id) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => ConductorRecogida(solicitudId: id)),
      );
    };
  }

  Future<bool> _solicitarPermisosUbicacion() async {
    final status = await Permission.location.request();
    return status == PermissionStatus.granted;
  }

  void _mostrarDialogoPermisoDenegado() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Permiso requerido'),
        content: const Text(
          'La aplicación necesita acceso a tu ubicación para funcionar correctamente.',
        ),
        actions: [
          TextButton(
            child: const Text('Abrir ajustes'),
            onPressed: () {
              openAppSettings();
              Navigator.of(context).pop();
            },
          ),
          TextButton(
            child: const Text('Cerrar'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colores.amarillo,
        title: const Text("Mapa Conductor"),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: () {
              final pos = controller?.currentPosition;
              if (pos != null) {
                _mapController?.animateCamera(
                  CameraUpdate.newLatLngZoom(pos, 15),
                );
              }
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          children: [
            DrawerHeader(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(color: Colores.amarillo),
              child: FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('conductor')
                    .doc(FirebaseAuth.instance.currentUser?.uid)
                    .get(),
                builder: (context, snapshot) {
                  final style = const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold);

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Row(
                      children: [
                        CircleAvatar(
                            radius: 30, child: CircularProgressIndicator()),
                        SizedBox(width: 16),
                        Text("Cargando...", style: TextStyle(fontSize: 20)),
                      ],
                    );
                  }

                  if (!snapshot.hasData || !snapshot.data!.exists) {
                    return const Row(
                      children: [
                        CircleAvatar(
                            radius: 30, child: Icon(Icons.person, size: 40)),
                        SizedBox(width: 16),
                        Text("Conductor no encontrado",
                            style: TextStyle(fontSize: 20)),
                      ],
                    );
                  }

                  final conductorData = snapshot.data!;
                  final String conductorName =
                      conductorData['nombre']?.toUpperCase() ?? "SIN NOMBRE";

                  return Row(
                    children: [
                      const SizedBox(width: 8),
                      Expanded(child: Text(conductorName, style: style)),
                    ],
                  );
                },
              ),
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Cerrar Sesión'),
              onTap: () async {
                await FirebaseAuth.instance.signOut();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const home()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('Historial de Viajes'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const DetallesViaje(solicitudId: ''),
                  ),
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
              target: controller?.currentPosition ??
                  const LatLng(8.2595534, -73.353469),
              zoom: 15,
            ),
            onMapCreated: (c) => _mapController = c,
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
          ),
          if (conectadoLocal != null)
            Positioned(
              bottom: 80,
              left: 130,
              child: ElevatedButton(
                onPressed: () async {
                  final nuevoEstado = !conectadoLocal!;
                  await controller?.actualizarEstadoConductor(nuevoEstado);
                  setState(() {
                    conectadoLocal = nuevoEstado;
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: conectadoLocal! ? Colors.green : Colors.red,
                ),
                child: Text(
                  conectadoLocal! ? "🟢 Conectado" : "🔴 Desconectado",
                ),
              ),
            ),
          if (_solicitudStream != null)
            StreamBuilder<DocumentSnapshot>(
              stream: _solicitudStream,
              builder: (context, snapshot) {
                if (!snapshot.hasData || !snapshot.data!.exists) {
                  return const SizedBox.shrink();
                }

                final data = snapshot.data!.data() as Map<String, dynamic>;
                final GeoPoint origen = data['ubicacion_inicial'];
                final String destino = data['direccion_seleccionada'] ?? "";
                final String clienteId = data['clienteId'];

                return FutureBuilder<List<String>>(
                  future: Future.wait([
                    controller?.obtenerNombreCliente(clienteId) ??
                        Future.value("Cliente"),
                    controller?.obtenerDireccion(origen) ??
                        Future.value("Ubicación"),
                  ]),
                  builder: (_, snapshot) {
                    if (!snapshot.hasData) return const SizedBox.shrink();
                    final nombre = snapshot.data![0];
                    final dir = snapshot.data![1];

                    return Positioned(
                      bottom: 16,
                      left: 16,
                      right: 16,
                      child: Card(
                        elevation: 5,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "🚖 Solicitud Entrante",
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Text("🛤 Origen: $dir",
                                  style: const TextStyle(fontSize: 16)),
                              const SizedBox(height: 8),
                              Text("📍 Destino: $destino",
                                  style: const TextStyle(fontSize: 16)),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  CustomButton(
                                    text: 'Rechazar',
                                    onPressed: () =>
                                        setState(() => _solicitudStream = null),
                                    width: 145,
                                    height: 50,
                                    fontSize: 16,
                                    icon: const Icon(Icons.cancel),
                                  ),
                                  CustomButton(
                                    text: 'Aceptar',
                                    onPressed: () =>
                                        controller?.aceptarSolicitud(),
                                    width: 145,
                                    height: 50,
                                    fontSize: 16,
                                    icon: const Icon(Icons.check),
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

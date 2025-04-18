import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:taxi_app/components/colores.dart';
import 'package:taxi_app/controllers/conductor_controller.dart';
import 'package:taxi_app/screens/conductor/ruta_cliente_conductor.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:taxi_app/screens/home.dart';

class MapaConductor extends StatefulWidget {
  const MapaConductor({super.key});

  @override
  State<MapaConductor> createState() => _MapaConductorState();
}

class _MapaConductorState extends State<MapaConductor> {
  late final MapaConductorController controller;
  late GoogleMapController _mapController;
  final Set<Marker> _markers = {};
  Stream<DocumentSnapshot>? _solicitudStream;

  @override
  void initState() {
    super.initState();
    controller = MapaConductorController()
      ..configurarNotificaciones()
      ..recuperarEstadoConductor()
      ..guardarTokenFCM()
      ..iniciarSeguimientoUbicacion((pos) {
        _mapController.animateCamera(CameraUpdate.newLatLng(pos));
      });

    controller.onNuevaSolicitud = (id) {
      setState(() {
        _solicitudStream = FirebaseFirestore.instance
            .collection('solicitud')
            .doc(id)
            .snapshots();
      });
    };

    controller.onSolicitudCancelada = () {
      setState(() {
        _solicitudStream = null;
      });
    };

    controller.onSolicitudAceptada = (id) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => ConductorRecogida(solicitudId: id)),
      );
    };
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colores.amarillo,
        title: const Text("Mapa Conductor"),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: () {
              if (controller.currentPosition != null) {
                _mapController.animateCamera(CameraUpdate.newLatLngZoom(
                    controller.currentPosition!, 15));
              }
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: Colores.amarillo),
              child: Text("Bienvenido, ${user?.email ?? 'Conductor'}"),
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
          ],
        ),
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: controller.currentPosition ?? const LatLng(4.6, -74.1),
              zoom: 15,
            ),
            onMapCreated: (c) => _mapController = c,
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
          ),
          Positioned(
            bottom: 80,
            left: 50,
            child: ElevatedButton(
              onPressed: () {
                controller.actualizarEstadoConductor(!controller.conectado);
                setState(() {});
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor:
                      controller.conectado ? Colors.green : Colors.red),
              child: Text(
                controller.conectado ? "🟢 Conectado" : "🔴 Desconectado",
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

                return FutureBuilder(
                  future: Future.wait([
                    controller.obtenerNombreCliente(clienteId),
                    controller.obtenerDireccion(origen),
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
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              Text("🚖 Solicitud de $nombre"),
                              Text("🛤 Origen: $dir"),
                              Text("📍 Destino: $destino"),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: () =>
                                        setState(() => _solicitudStream = null),
                                    icon: const Icon(Icons.cancel),
                                    label: const Text("Rechazar"),
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red),
                                  ),
                                  ElevatedButton.icon(
                                    onPressed: () =>
                                        controller.aceptarSolicitud(),
                                    icon: const Icon(Icons.check),
                                    label: const Text("Aceptar"),
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green),
                                  ),
                                ],
                              )
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            )
        ],
      ),
    );
  }
}

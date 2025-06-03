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
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:vibration/vibration.dart';

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
  bool? conectadoLocal;

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    FocusManager.instance.primaryFocus?.unfocus();
    _solicitarPermisosUbicacion().then((granted) {
      if (granted) {
        _inicializarNotificaciones();
        _inicializarController();
      } else {
        _mostrarDialogoPermisoDenegado();
      }
    });
  }

  Future<void> _inicializarNotificaciones() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings =
        InitializationSettings(android: androidSettings);
    await flutterLocalNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {},
    );
  }

  Future<void> _mostrarNotificacionLocal(String titulo, String cuerpo) async {
    final androidDetails = AndroidNotificationDetails(
      'canal_solicitudes',
      'Solicitudes',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    final notificationDetails = NotificationDetails(android: androidDetails);

    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(duration: 500);
    }

    await flutterLocalNotificationsPlugin.show(
      0,
      titulo,
      cuerpo,
      notificationDetails,
    );
  }

  void _inicializarController() async {
    controller = MapaConductorController()
      ..configurarNotificaciones()
      ..iniciarSeguimientoUbicacion((pos) {
        _mapController?.animateCamera(CameraUpdate.newLatLng(pos));
      });

    await controller!.recuperarEstadoConductor();
    setState(() => conectadoLocal = controller!.conectado);

    controller!.onNuevaSolicitud = (id) async {
      setState(() {
        _solicitudStream = FirebaseFirestore.instance
            .collection('solicitud')
            .doc(id)
            .snapshots();
      });

      await _mostrarNotificacionLocal(
        "🚖 Nueva solicitud",
        "Tienes una nueva solicitud pendiente",
      );
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
            'La aplicación necesita acceso a tu ubicación para funcionar correctamente.'),
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

  Widget _botonConexion(double scale) {
    return Positioned(
      bottom: 80,
      left: 130 * scale,
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
          padding: EdgeInsets.symmetric(
              horizontal: 24 * scale, vertical: 12 * scale),
          textStyle:
              TextStyle(fontSize: 16 * scale, fontWeight: FontWeight.bold),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12 * scale),
          ),
        ),
        child: Text(
          conectadoLocal! ? "🟢 Conectado" : "🔴 Desconectado",
        ),
      ),
    );
  }

  Widget _drawerConductor(double scale) {
    return Drawer(
      child: ListView(
        children: [
          DrawerHeader(
            padding: EdgeInsets.all(16 * scale),
            decoration: BoxDecoration(color: Colores.amarillo),
            child: FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('conductor')
                  .doc(FirebaseAuth.instance.currentUser?.uid)
                  .get(),
              builder: (context, snapshot) {
                final style = TextStyle(
                    fontSize: 20 * scale, fontWeight: FontWeight.bold);
                if (!snapshot.hasData || !snapshot.data!.exists) {
                  return const Text("Conductor no encontrado");
                }
                final data = snapshot.data!;
                final String name =
                    data['nombre']?.toUpperCase() ?? 'SIN NOMBRE';
                return Row(
                  children: [
                    const CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.white,
                      child: Icon(Icons.person, color: Colors.grey),
                    ),
                    SizedBox(width: 16 * scale),
                    Expanded(child: Text(name, style: style)),
                  ],
                );
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title:
                Text('Cerrar Sesión', style: TextStyle(fontSize: 16 * scale)),
            onTap: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const Home()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.history),
            title: Text('Historial de Viajes',
                style: TextStyle(fontSize: 16 * scale)),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const HistorialConductor(),
                ),
              );
            },
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
    final screenWidth = MediaQuery.of(context).size.width;
    final scale = screenWidth / 375;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colores.amarillo,
          title: Text("Mapa Conductor",
              style:
                  TextStyle(fontSize: 20 * scale, fontWeight: FontWeight.bold)),
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
        drawer: _drawerConductor(scale),
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
            if (conectadoLocal != null) _botonConexion(scale),
            if (_solicitudStream != null)
              StreamBuilder<DocumentSnapshot>(
                stream: _solicitudStream,
                builder: (context, snapshot) {
                  if (!snapshot.hasData || !snapshot.data!.exists) {
                    return const SizedBox.shrink();
                  }

                  final data = snapshot.data!.data() as Map<String, dynamic>;
                  if (data['estado'] != 'pendiente')
                    return const SizedBox.shrink();

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
                            padding: EdgeInsets.all(16 * scale),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("🚖 Solicitud Entrante",
                                    style: TextStyle(
                                        fontSize: 18 * scale,
                                        fontWeight: FontWeight.bold)),
                                SizedBox(height: 8 * scale),
                                Text("🛤 Origen: $dir",
                                    style: TextStyle(fontSize: 14 * scale)),
                                SizedBox(height: 4 * scale),
                                Text("📍 Destino: $destino",
                                    style: TextStyle(fontSize: 14 * scale)),
                                SizedBox(height: 16 * scale),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    CustomButton(
                                      text: 'Rechazar',
                                      onPressed: () => setState(
                                          () => _solicitudStream = null),
                                      width: 145 * scale,
                                      height: 50 * scale,
                                      fontSize: 16 * scale,
                                      icon: const Icon(Icons.cancel),
                                    ),
                                    CustomButton(
                                      text: 'Aceptar',
                                      onPressed: () =>
                                          controller?.aceptarSolicitud(),
                                      width: 145 * scale,
                                      height: 50 * scale,
                                      fontSize: 16 * scale,
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
      ),
    );
  }
}

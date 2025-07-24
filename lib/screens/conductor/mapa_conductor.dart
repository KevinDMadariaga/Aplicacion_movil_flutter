import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:taxi_app/components/colores.dart';
import 'package:taxi_app/controllers/conductor_controller.dart';
import 'package:taxi_app/screens/conductor/historial_viajes_conductor.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:taxi_app/screens/home.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:taxi_app/utils/inicializador_conductor.dart';
import 'package:taxi_app/widgets/solicitud_pendiente.dart';
import 'package:vibration/vibration.dart';

class MapaConductor extends StatefulWidget {
  const MapaConductor({super.key});

  @override
  State<MapaConductor> createState() => _MapaConductorState();
}

class _MapaConductorState extends State<MapaConductor> {
  LatLng? _posicionActual;
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
    controller?.iniciarRastreoUbicacion(
      (pos) => setState(() {
        _posicionActual = pos;
        // Centrar el mapa en la posición actual cuando se obtiene
        if (_mapController != null && _posicionActual != null) {
          _mapController?.animateCamera(
            CameraUpdate.newLatLngZoom(_posicionActual!, 16.0),
          );
        }
      }),

      collection: 'conductor',
      docId: FirebaseAuth.instance.currentUser!.uid,
    );
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
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
    );
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
    controller = await inicializarMapaConductorController(
      context: context,
      onSolicitudStreamChange: (stream) {
        setState(() => _solicitudStream = stream);
      },
      onEstadoConectado: (estado) {
        setState(() => conectadoLocal = estado);
      },
      onUbicacion: (pos) {
        _mapController?.animateCamera(CameraUpdate.newLatLng(pos));
      },
      mostrarNotificacion: (titulo, cuerpo) =>
          _mostrarNotificacionLocal(titulo, cuerpo),
    );
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

  Widget _botonConexion(double scale) {
    return Positioned(
      bottom: 80,
      left: 110 * scale,
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
            horizontal: 20 * scale,
            vertical: 12 * scale,
          ),
          textStyle: TextStyle(
            fontSize: 16 * scale,
            fontWeight: FontWeight.bold,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12 * scale),
          ),
        ),
        child: Text(conectadoLocal! ? "🟢 Conectado" : "🔴 Desconectado"),
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
                  fontSize: 20 * scale,
                  fontWeight: FontWeight.bold,
                );
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
            title: Text(
              'Cerrar Sesión',
              style: TextStyle(fontSize: 16 * scale),
            ),
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
            title: Text(
              'Historial de Viajes',
              style: TextStyle(fontSize: 16 * scale),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HistorialConductor()),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    controller?.detenerRastreo();
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
          title: Text(
            "Mapa Conductor",
            style: TextStyle(fontSize: 20 * scale, fontWeight: FontWeight.bold),
          ),
        ),
        drawer: _drawerConductor(scale),
        body: Stack(
          children: [
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _posicionActual ?? const LatLng(8.2595534, -73.353469),
                zoom: 15,
              ),
              onMapCreated: (controller) {
                _mapController = controller;
                if (_posicionActual != null) {
                  _mapController?.animateCamera(
                    CameraUpdate.newLatLngZoom(
                      _posicionActual!,
                      16.0,
                    ), // Centra el mapa en la ubicación del conductor
                  );
                }
              },
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              markers: {
                if (_posicionActual != null)
                  Marker(
                    markerId: const MarkerId('ubicacion_actual'),
                    position: _posicionActual!,
                    icon: BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueBlue,
                    ),
                  ),
              },
            ),
            if (conectadoLocal != null) _botonConexion(scale),
            if (_solicitudStream != null)
              SolicitudPendienteWidget(
                stream: _solicitudStream!,
                scale: scale,
                obtenerNombreCliente: controller!.obtenerNombreCliente,
                obtenerDireccion: controller!.obtenerDireccion,
                onAceptar: () => controller?.aceptarSolicitud(),
                onRechazar: () => setState(() => _solicitudStream = null),
              ),
          ],
        ),
      ),
    );
  }
}

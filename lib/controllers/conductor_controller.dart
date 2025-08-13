import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapaConductorController {
  final User conductor = FirebaseAuth.instance.currentUser!;
  StreamSubscription<Position>? _positionStream;
  StreamSubscription<Position>? _subscription;
  StreamSubscription<QuerySnapshot>? _solicitudesSubscription;
  StreamSubscription<DocumentSnapshot>? _solicitudDocSubscription;

  LatLng? currentPosition;
  LatLng? _ultimaUbicacionEnviada;

  bool conectado = true;
  String? solicitudId;

  Function(String)? onNuevaSolicitud;
  Function()? onSolicitudCancelada;
  Function(String)? onSolicitudAceptada;

  /// Inicializa estado y escucha notificaciones
  Future<void> recuperarEstadoConductor() async {
    final doc = await FirebaseFirestore.instance
        .collection('conductor')
        .doc(conductor.uid)
        .get();

    if (doc.exists) {
      conectado = doc.data()?['conectado'] ?? true;
    } else {
      await FirebaseFirestore.instance
          .collection('conductor')
          .doc(conductor.uid)
          .set({'conectado': true});
      conectado = true;
    }
  }

  Future<void> actualizarEstadoConductor(bool estado) async {
    conectado = estado;
    await FirebaseFirestore.instance
        .collection('conductor')
        .doc(conductor.uid)
        .update({'conectado': estado});
  }

  void configurarNotificaciones() {
    _solicitudesSubscription = FirebaseFirestore.instance
        .collection('solicitud')
        .where('estado', isEqualTo: 'pendiente')
        .snapshots()
        .listen((snapshot) {
      if (!conectado) return;
      for (var doc in snapshot.docs) {
        if (solicitudId != doc.id) {
          solicitudId = doc.id;
          onNuevaSolicitud?.call(doc.id);
          break;
        }
      }
    });
  }

  void escucharCambiosSolicitud(String id) {
    _solicitudDocSubscription?.cancel();
    _solicitudDocSubscription = FirebaseFirestore.instance
        .collection('solicitud')
        .doc(id)
        .snapshots()
        .listen((doc) {
      if (!doc.exists) return;

      final estado = doc['estado'];
      if (estado == 'aceptada') {
        onSolicitudAceptada?.call(id);
      } else if (estado == 'cancelada') {
        solicitudId = null;
        onSolicitudCancelada?.call();
      }
    });
  }

  Future<void> aceptarSolicitud() async {
    if (solicitudId == null) return;

    await FirebaseFirestore.instance
        .collection('solicitud')
        .doc(solicitudId)
        .update({
      'estado': 'aceptada',
      'conductorId': conductor.uid,
      'hora_aceptacion': DateTime.now(),
    });

    escucharCambiosSolicitud(solicitudId!);
  }

  Future<String> obtenerNombreCliente(String id) async {
    try {
      final doc =
          await FirebaseFirestore.instance.collection('cliente').doc(id).get();
      return doc.exists ? doc['nombre'] ?? 'Desconocido' : 'Desconocido';
    } catch (_) {
      return 'Desconocido';
    }
  }

  //direccion del cliente
  Future<String> obtenerDireccion(GeoPoint ubicacion) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        ubicacion.latitude,
        ubicacion.longitude,
      );
      if (placemarks.isEmpty) return "Dirección desconocida";

      final p = placemarks.first;
      return "${p.street ?? ''}, ${p.locality ?? ''}, ${p.administrativeArea ?? ''}";
    } catch (_) {
      return "Dirección desconocida";
    }
  }

  /// Inicia el rastreo y guarda en Firestore
  void iniciarRastreoUbicacion(
    Function(LatLng) onUbicacion, {
    required String collection,
    String? docId,
  }) async {
    final permiso = await _verificarPermisos();
    if (!permiso) return;

    final settings = const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );

    _positionStream = Geolocator.getPositionStream(locationSettings: settings)
        .listen((Position pos) {
      final latLng = LatLng(pos.latitude, pos.longitude);
      onUbicacion(latLng);
      currentPosition = latLng;

      final user = FirebaseAuth.instance.currentUser;
      final String? id = docId ?? user?.uid;

      if (id != null) {
        FirebaseFirestore.instance.collection(collection).doc(id).set({
          'ubicacion': GeoPoint(pos.latitude, pos.longitude),
          'actualizado': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    });
  }

  /// Detiene el rastreo de ubicación.
  void detenerRastreo() {
    _positionStream?.cancel();
  }

  /// Solicita y verifica los permisos de ubicación.
  Future<bool> _verificarPermisos() async {
    LocationPermission permiso = await Geolocator.checkPermission();
    if (permiso == LocationPermission.denied ||
        permiso == LocationPermission.deniedForever) {
      permiso = await Geolocator.requestPermission();
    }
    return permiso == LocationPermission.always ||
        permiso == LocationPermission.whileInUse;
  }
}

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapaConductorController {
  final User conductor = FirebaseAuth.instance.currentUser!;
  StreamSubscription<Position>? _positionStream;
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

  Future<void> iniciarSeguimientoUbicacion(Function(LatLng) onUpdate) async {
    final permisos = await Geolocator.checkPermission();
    if (permisos == LocationPermission.denied ||
        permisos == LocationPermission.deniedForever) return;

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    _positionStream?.cancel();
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((pos) {
      final nuevaUbicacion = LatLng(pos.latitude, pos.longitude);
      currentPosition = nuevaUbicacion;
      onUpdate(nuevaUbicacion);

      if (_debeActualizarUbicacion(nuevaUbicacion)) {
        _ultimaUbicacionEnviada = nuevaUbicacion;

        FirebaseFirestore.instance
            .collection('conductor')
            .doc(conductor.uid)
            .update({
          'ubicacion': GeoPoint(pos.latitude, pos.longitude),
          'ultima_actualizacion': DateTime.now(),
        });
      }
    });
  }

  bool _debeActualizarUbicacion(LatLng nueva) {
    if (_ultimaUbicacionEnviada == null) return true;

    final distancia = Geolocator.distanceBetween(
      _ultimaUbicacionEnviada!.latitude,
      _ultimaUbicacionEnviada!.longitude,
      nueva.latitude,
      nueva.longitude,
    );

    return distancia > 4; // Solo actualiza si se movió más de 20 metros
  }

  void dispose() {
    _positionStream?.cancel();
    _solicitudesSubscription?.cancel();
    _solicitudDocSubscription?.cancel();
  }
}

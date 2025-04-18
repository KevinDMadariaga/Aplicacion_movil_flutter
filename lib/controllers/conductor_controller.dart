import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapaConductorController {
  final User conductor = FirebaseAuth.instance.currentUser!;
  StreamSubscription<Position>? positionStreamSubscription;
  Stream<DocumentSnapshot>? solicitudStream;
  LatLng? currentPosition;
  bool conectado = true;
  String? solicitudId;
  Function(String)? onNuevaSolicitud;
  Function()? onSolicitudCancelada;
  Function(String)? onSolicitudAceptada;

  Future<void> recuperarEstadoConductor() async {
    DocumentSnapshot doc = await FirebaseFirestore.instance
        .collection('conductor')
        .doc(conductor.uid)
        .get();

    conectado = doc.exists ? doc['conectado'] ?? true : true;
  }

  Future<void> actualizarEstadoConductor(bool estado) async {
    conectado = estado;
    await FirebaseFirestore.instance
        .collection('conductor')
        .doc(conductor.uid)
        .update({'conectado': estado});
  }

  Future<void> guardarTokenFCM() async {
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) {
      await FirebaseFirestore.instance
          .collection('conductor')
          .doc(conductor.uid)
          .update({'token_fcm': token});
    }
  }

  void configurarNotificaciones() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      final doc = await FirebaseFirestore.instance
          .collection('conductor')
          .doc(conductor.uid)
          .get();

      if (doc.exists && doc['conectado'] == true) {
        if (message.data.containsKey('solicitudId')) {
          final id = message.data['solicitudId'];
          if (solicitudId != id) {
            solicitudId = id;
            onNuevaSolicitud?.call(id);
          }
        }
      }
    });

    FirebaseFirestore.instance
        .collection('conductor')
        .doc(conductor.uid)
        .snapshots()
        .listen((doc) {
      if (doc.exists && doc['conectado'] == true) {
        FirebaseFirestore.instance
            .collection('solicitud')
            .where('estado', isEqualTo: 'pendiente')
            .snapshots()
            .listen((snapshot) {
          for (var doc in snapshot.docs) {
            if (solicitudId != doc.id) {
              solicitudId = doc.id;
              onNuevaSolicitud?.call(doc.id);
            }
          }
        });
      }
    });
  }

  void escucharCambiosSolicitud(String id) {
    FirebaseFirestore.instance
        .collection('solicitud')
        .doc(id)
        .snapshots()
        .listen((doc) {
      if (doc.exists) {
        final estado = doc['estado'] ?? '';
        if (estado == 'aceptada') {
          onSolicitudAceptada?.call(id);
        }
        if (estado == 'cancelada') {
          solicitudId = null;
          solicitudStream = null;
          onSolicitudCancelada?.call();
        }
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
    });
    escucharCambiosSolicitud(solicitudId!);
  }

  Future<String> obtenerNombreCliente(String id) async {
    final doc =
        await FirebaseFirestore.instance.collection('cliente').doc(id).get();
    return doc.exists ? doc['nombre'] ?? 'Desconocido' : 'Desconocido';
  }

  Future<String> obtenerDireccion(GeoPoint ubicacion) async {
    try {
      final placemarks = await placemarkFromCoordinates(
          ubicacion.latitude, ubicacion.longitude);
      if (placemarks.isEmpty) return "Dirección desconocida";

      final p = placemarks.first;
      return "${p.street ?? ''}, ${p.locality ?? ''}, ${p.administrativeArea ?? ''}";
    } catch (_) {
      return "Dirección desconocida";
    }
  }

  Future<void> iniciarSeguimientoUbicacion(Function(LatLng) onUpdate) async {
    final permisos = await Geolocator.requestPermission();
    if (permisos == LocationPermission.denied ||
        permisos == LocationPermission.deniedForever) return;

    positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((pos) {
      final ubicacion = LatLng(pos.latitude, pos.longitude);
      currentPosition = ubicacion;
      onUpdate(ubicacion);
      FirebaseFirestore.instance
          .collection('conductor')
          .doc(conductor.uid)
          .update({'ubicacion': GeoPoint(pos.latitude, pos.longitude)});
    });
  }

  void dispose() {
    positionStreamSubscription?.cancel();
  }
}

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class UbicacionController {
  StreamSubscription<Position>? _subscription;

  void iniciarRastreoUbicacion(
    Function(LatLng) onUbicacion, {
    required String collection,
    String? docId, // Permite indicar el ID del documento
  }) async {
    final permiso = await _verificarPermisos();
    if (!permiso) return;

    final settings = const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );

    _subscription = Geolocator.getPositionStream(locationSettings: settings)
        .listen((Position pos) {
          final latLng = LatLng(pos.latitude, pos.longitude);
          onUbicacion(latLng);

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

  void detenerRastreo() {
    _subscription?.cancel();
  }

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

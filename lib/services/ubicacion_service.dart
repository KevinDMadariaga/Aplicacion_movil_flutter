import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class UbicacionService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  StreamSubscription<Position>? _positionStream;

  Future<LatLng?> obtenerUbicacionActual() async {
    if (!await Geolocator.isLocationServiceEnabled()) return null;

    LocationPermission permiso = await Geolocator.checkPermission();
    if (permiso == LocationPermission.denied) {
      permiso = await Geolocator.requestPermission();
    }
    if (permiso == LocationPermission.deniedForever) return null;

    Position posicion = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    return LatLng(posicion.latitude, posicion.longitude);
  }

  void escucharUbicacion(void Function(Position) onUbicacionCambio) {
    _positionStream?.cancel();
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen(onUbicacionCambio);
  }

  void actualizarUbicacionFirestore(Position posicion) {
    final usuario = _auth.currentUser;
    if (usuario != null) {
      FirebaseFirestore.instance
          .collection('conductor')
          .doc(usuario.uid)
          .update({
        'ubicacion': GeoPoint(posicion.latitude, posicion.longitude)
      });
    }
  }

  void detenerEscucha() {
    _positionStream?.cancel();
  }
}

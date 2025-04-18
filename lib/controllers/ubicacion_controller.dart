import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class UbicacionController {
  StreamSubscription<Position>? _subscription;
  LatLng? posicionActual;

  Future<bool> verificarPermisos() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
    }

    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  Future<LatLng?> obtenerUbicacionInicial() async {
    if (!await verificarPermisos()) return null;

    Position posicion = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    posicionActual = LatLng(posicion.latitude, posicion.longitude);
    return posicionActual;
  }

  void escucharUbicacion(void Function(Position) onUpdate) {
    _subscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen(onUpdate);
  }

  void detener() {
    _subscription?.cancel();
  }
}

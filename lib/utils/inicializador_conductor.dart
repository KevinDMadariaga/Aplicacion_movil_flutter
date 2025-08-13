import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:taxi_app/controllers/conductor_controller.dart';
import 'package:taxi_app/screens/conductor/ruta_cliente_conductor.dart';

Future<MapaConductorController> inicializarMapaConductorController({
  required BuildContext context,
  required void Function(Stream<DocumentSnapshot>) onSolicitudStreamChange,
  required void Function(bool) onEstadoConectado,
  required void Function(LatLng) onUbicacion,
  required Future<void> Function(String, String) mostrarNotificacion,
}) async {
  final controller = MapaConductorController()
    ..configurarNotificaciones()
    ..iniciarRastreoUbicacion(
      onUbicacion,
      collection: 'conductor',
    );

  await controller.recuperarEstadoConductor();
  onEstadoConectado(controller.conectado);

  controller.onNuevaSolicitud = (id) async {
    final stream = FirebaseFirestore.instance
        .collection('solicitud')
        .doc(id)
        .snapshots();
    onSolicitudStreamChange(stream);

    await mostrarNotificacion(
      "🚖 Nueva solicitud",
      "Tienes una nueva solicitud pendiente",
    );
  };

  controller.onSolicitudCancelada = () {
    onSolicitudStreamChange(Stream.empty());
  };

  controller.onSolicitudAceptada = (id) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => ConductorRecogida(solicitudId: id)),
    );
  };

  return controller;
}

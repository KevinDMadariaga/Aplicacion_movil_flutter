import 'package:flutter/material.dart';

class ClienteConductor extends StatelessWidget {
  final String ubicacionSeleccionada;

  const ClienteConductor({
    super.key,
    required this.ubicacionSeleccionada,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Cliente - Conductor"),
      ),
      body: Center(
        child: Text(
          'Ubicación Seleccionada: $ubicacionSeleccionada',
          style: const TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}

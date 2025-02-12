import 'package:flutter/material.dart';

class ClienteConductor extends StatelessWidget {
  final String ubicacionSeleccionada;

  const ClienteConductor({
    Key? key,
    required this.ubicacionSeleccionada,
  }) : super(key: key);

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

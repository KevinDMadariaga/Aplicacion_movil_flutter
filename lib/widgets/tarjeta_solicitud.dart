import 'package:flutter/material.dart';

class TarjetaSolicitud extends StatelessWidget {
  final String nombreCliente;
  final String direccionOrigen;
  final String direccionDestino;
  final VoidCallback onAceptar;
  final VoidCallback onRechazar;

  const TarjetaSolicitud({
    super.key,
    required this.nombreCliente,
    required this.direccionOrigen,
    required this.direccionDestino,
    required this.onAceptar,
    required this.onRechazar,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 20,
      left: 16,
      right: 16,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("🚖 Nueva Solicitud Recibida",
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87)),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.person, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text("Cliente: $nombreCliente",
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w500)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.location_on, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text("🛤 Origen: $direccionOrigen",
                        style: const TextStyle(fontSize: 15)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.flag, color: Colors.green),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text("📍 Destino: $direccionDestino",
                        style: const TextStyle(fontSize: 15)),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton.icon(
                    onPressed: onRechazar,
                    icon: const Icon(Icons.cancel, color: Colors.white),
                    label: const Text("Rechazar",
                        style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: onAceptar,
                    icon: const Icon(Icons.check_circle, color: Colors.white),
                    label: const Text("Aceptar",
                        style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}

// Importaciones necesarias
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geocoding/geocoding.dart';
import 'package:taxi_app/screens/cliente/mapa_cliente.dart';

class ResumenSolicitud extends StatefulWidget {
  final String solicitudId;

  const ResumenSolicitud({Key? key, required this.solicitudId})
      : super(key: key);

  @override
  State<ResumenSolicitud> createState() => _ResumenSolicitudState();
}

class _ResumenSolicitudState extends State<ResumenSolicitud> {
  double _calificacion = 1.0;
  bool _yaCalificada = false;
  String _direccionRecogida = "Cargando dirección...";

  String formatoHoraBogota(Timestamp timestamp) {
    final fecha = timestamp.toDate().toUtc().subtract(const Duration(hours: 5));
    return "${fecha.day.toString().padLeft(2, '0')}/"
        "${fecha.month.toString().padLeft(2, '0')}/"
        "${fecha.year} ${fecha.hour.toString().padLeft(2, '0')}:"
        "${fecha.minute.toString().padLeft(2, '0')}";
  }

  Future<void> _verificarYRecuperarCalificacion(String solicitudId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('historial viaje')
        .where('solicitudId', isEqualTo: solicitudId)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      final calificacion = snapshot.docs.first['calificacion'];
      setState(() {
        _yaCalificada = true;
        _calificacion = (calificacion as int).toDouble();
      });
    }
  }

  Future<void> _obtenerDireccionRecogida(double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty && mounted) {
        final p = placemarks.first;
        setState(() {
          _direccionRecogida = "${p.street}, ${p.locality}, ${p.country}";
        });
      }
    } catch (_) {
      setState(() {
        _direccionRecogida = "Dirección no disponible";
      });
    }
  }

  Future<void> _guardarCalificacion(Map<String, dynamic> data,
      String nombreConductor, String nombreCliente) async {
    final horaInicio = data['hora_aceptacion'] as Timestamp?;
    final horaFin = data['fecha_terminacion'] as Timestamp?;
    final duracion = (horaInicio != null && horaFin != null)
        ? horaFin.toDate().difference(horaInicio.toDate()).inMinutes
        : 0;

    await FirebaseFirestore.instance.collection('historial viaje').add({
      'solicitudId': widget.solicitudId,
      'clienteId': data['clienteId'],
      'conductorId': data['conductorId'],
      'direccion_inicial': data['ubicacion_inicial'],
      'direccion_destino': data['direccion_seleccionada'],
      'hora_aceptacion': horaInicio,
      'fecha_termino': horaFin,
      'duracion_minutos': duracion,
      'calificacion': _calificacion,
      'conductor_nombre': nombreConductor,
      'cliente_nombre': nombreCliente,
    });

    setState(() => _yaCalificada = true);
  }

  @override
  void initState() {
    super.initState();
    _verificarYRecuperarCalificacion(widget.solicitudId);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final scale = width / 375;
    final fontSize = 18 * scale;
    final buttonHeight = 50 * scale;
    final iconSize = 36 * scale;

    return Scaffold(
      backgroundColor: Colors.white,
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('solicitud')
            .doc(widget.solicitudId)
            .get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("No se encontraron datos"));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final conductorId = data['conductorId'];
          final clienteId = data['clienteId'];
          final geo = data['ubicacion_inicial'];
          final direccionSeleccionada = data['direccion_seleccionada'];
          final horaInicio = data['hora_aceptacion'] as Timestamp?;
          final horaFin = data['fecha_terminacion'] as Timestamp?;
          final valorServicio = data['valor_servicio'] ?? 0;

          _obtenerDireccionRecogida(geo.latitude, geo.longitude);

          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('conductor')
                .doc(conductorId)
                .get(),
            builder: (context, conductorSnapshot) {
              if (!conductorSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final nombreConductor =
                  conductorSnapshot.data!['nombre']?.toString().toUpperCase() ??
                      "CONDUCTOR";

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('cliente')
                    .doc(clienteId)
                    .get(),
                builder: (context, clienteSnapshot) {
                  if (!clienteSnapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final nombreCliente =
                      clienteSnapshot.data!['nombre'] ?? "Cliente";

                  return SafeArea(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.symmetric(
                          horizontal: 24 * scale, vertical: 16 * scale),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Image.asset(
                              'assets/img/taxi.png',
                              height: 150 * scale,
                              fit: BoxFit.contain,
                            ),
                          ),
                          SizedBox(height: 24 * scale),
                          Row(
                            children: [
                              Icon(Icons.person,
                                  size: iconSize, color: Color(0xFFFFD600)),
                              SizedBox(width: 8 * scale),
                              Text(nombreConductor,
                                  style: TextStyle(
                                    fontSize: 22 * scale,
                                    fontWeight: FontWeight.bold,
                                  )),
                            ],
                          ),
                          SizedBox(height: 30 * scale),
                          Text("📍 Dirección de Recogida:",
                              style: TextStyle(
                                  fontSize: fontSize,
                                  fontWeight: FontWeight.w600)),
                          Text(_direccionRecogida,
                              style: TextStyle(
                                  fontSize: fontSize * 0.9,
                                  fontWeight: FontWeight.bold)),
                          SizedBox(height: 16 * scale),
                          Text("🏁 Dirección de Destino:",
                              style: TextStyle(
                                  fontSize: fontSize,
                                  fontWeight: FontWeight.w600)),
                          Text(direccionSeleccionada ?? "No disponible",
                              style: TextStyle(
                                  fontSize: fontSize * 0.9,
                                  fontWeight: FontWeight.bold)),
                          if (horaInicio != null) ...[
                            SizedBox(height: 16 * scale),
                            Text("🕓 Hora de Inicio:",
                                style: TextStyle(
                                    fontSize: fontSize,
                                    fontWeight: FontWeight.w600)),
                            Text(formatoHoraBogota(horaInicio),
                                style: TextStyle(
                                    fontSize: fontSize * 0.9,
                                    fontWeight: FontWeight.bold)),
                          ],
                          if (horaFin != null) ...[
                            SizedBox(height: 16 * scale),
                            Text("🕓 Hora de Finalización:",
                                style: TextStyle(
                                    fontSize: fontSize,
                                    fontWeight: FontWeight.w600)),
                            Text(formatoHoraBogota(horaFin),
                                style: TextStyle(
                                    fontSize: fontSize * 0.9,
                                    fontWeight: FontWeight.bold)),
                          ],
                          SizedBox(height: 16 * scale),
                          Text("💲 Valor del Servicio:",
                              style: TextStyle(
                                  fontSize: fontSize,
                                  fontWeight: FontWeight.w600)),
                          Text(
                            valorServicio > 0
                                ? "\$${valorServicio.toString()}"
                                : "No disponible",
                            style: TextStyle(
                                fontSize: fontSize * 0.9,
                                fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 16 * scale),
                          if (!_yaCalificada) ...[
                            Text("😊 Califica tu experiencia:",
                                style: TextStyle(
                                    fontSize: fontSize,
                                    fontWeight: FontWeight.w600)),
                            SizedBox(height: 16 * scale),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [1, 2, 3].map((int valor) {
                                final color = valor == 1
                                    ? Colors.red
                                    : valor == 2
                                        ? Colors.orange
                                        : Colors.green;
                                final emoji = valor == 1
                                    ? "😡"
                                    : valor == 2
                                        ? "🙂"
                                        : "😍";
                                final label = valor == 1
                                    ? "Malo"
                                    : valor == 2
                                        ? "Bueno"
                                        : "Excelente";
                                return GestureDetector(
                                  onTap: () => setState(
                                      () => _calificacion = valor.toDouble()),
                                  child: Column(
                                    children: [
                                      Text(emoji,
                                          style: TextStyle(
                                              fontSize: 42 * scale,
                                              color: _calificacion == valor
                                                  ? color
                                                  : Colors.grey)),
                                      Text(label,
                                          style: TextStyle(
                                            fontSize: 14 * scale,
                                            color: _calificacion == valor
                                                ? color
                                                : Colors.grey,
                                            fontWeight: _calificacion == valor
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                          )),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                            SizedBox(height: 24 * scale),
                          ],
                          SizedBox(
                            width: width * 0.8,
                            height: buttonHeight,
                            child: ElevatedButton(
                              onPressed: () async {
                                if (_yaCalificada) {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => const MapaCliente()),
                                  );
                                } else if (_calificacion >= 1) {
                                  await _guardarCalificacion(
                                      data, nombreConductor, nombreCliente);
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => const MapaCliente()),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          "Por favor selecciona una calificación."),
                                    ),
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFFD600),
                                foregroundColor: Colors.black,
                                textStyle: TextStyle(
                                  fontSize: 16 * scale,
                                  fontWeight: FontWeight.bold,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(12 * scale),
                                ),
                              ),
                              child: Text(_yaCalificada
                                  ? "Volver al Mapa"
                                  : "Calificar y Volver"),
                            ),
                          ),
                          SizedBox(height: 30 * scale),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

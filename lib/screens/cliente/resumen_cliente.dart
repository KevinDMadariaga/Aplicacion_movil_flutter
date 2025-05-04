import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:taxi_app/components/colores.dart';
import 'package:taxi_app/screens/home.dart';

class ResumenSolicitud extends StatefulWidget {
  final String solicitudId;

  const ResumenSolicitud({Key? key, required this.solicitudId})
      : super(key: key);

  @override
  State<ResumenSolicitud> createState() => _ResumenSolicitudState();
}

class _ResumenSolicitudState extends State<ResumenSolicitud> {
  double _calificacion = 0.0;
  bool _yaCalificada = false;

  String formatoHoraBogota(Timestamp timestamp) {
    final fecha = timestamp.toDate().toUtc().subtract(const Duration(hours: 5));
    final dia = fecha.day.toString().padLeft(2, '0');
    final mes = fecha.month.toString().padLeft(2, '0');
    final anio = fecha.year;
    final hora = fecha.hour.toString().padLeft(2, '0');
    final minuto = fecha.minute.toString().padLeft(2, '0');
    return "$dia/$mes/$anio $hora:$minuto";
  }

  String obtenerDuracion(Timestamp inicio, Timestamp fin) {
    final duracion = fin.toDate().difference(inicio.toDate());
    final minutos = duracion.inMinutes;
    return "$minutos minuto${minutos == 1 ? '' : 's'}";
  }

  Future<bool> _verificarSiYaCalifico(String solicitudId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('historial viaje')
        .where('solicitudId', isEqualTo: solicitudId)
        .get();

    return snapshot.docs.isNotEmpty;
  }

  Future<void> _guardarCalificacion(
    Map<String, dynamic> data,
    String nombreConductor,
    String nombreCliente,
  ) async {
    final calificacion = _calificacion.toInt();
    final inicio = data['hora_aceptacion'] as Timestamp?;
    final fin = data['fecha_termino'] as Timestamp?;

    final duracion = (inicio != null && fin != null)
        ? fin.toDate().difference(inicio.toDate()).inMinutes
        : 0;

    await FirebaseFirestore.instance.collection('historial viaje').add({
      'solicitudId': widget.solicitudId,
      'clienteId': data['clienteId'],
      'conductorId': data['conductorId'],
      'direccion_inicial': data['ubicacion_inicial'],
      'direccion_destino': data['direccion_seleccionada'],
      'hora_aceptacion': data['hora_aceptacion'],
      'fecha_termino': data['fecha_termino'],
      'duracion_minutos': duracion,
      'calificacion': calificacion,
      'conductor_nombre': nombreConductor,
      'cliente_nombre': nombreCliente,
    });

    final conductorRef = FirebaseFirestore.instance
        .collection('conductor')
        .doc(data['conductorId']);

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(conductorRef);
      final currentSum = snapshot['suma_calificaciones'] ?? 0;
      final currentCount = snapshot['total_calificaciones'] ?? 0;

      final newSum = currentSum + calificacion;
      final newCount = currentCount + 1;
      final newAverage = newSum / newCount;

      transaction.update(conductorRef, {
        'suma_calificaciones': newSum,
        'total_calificaciones': newCount,
        'promedio_calificacion': newAverage,
      });
    });

    setState(() => _yaCalificada = true);
  }

  @override
  void initState() {
    super.initState();
    _verificarSiYaCalifico(widget.solicitudId).then((calificada) {
      if (mounted) {
        setState(() => _yaCalificada = calificada);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
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
          final direccionSeleccionada = data['direccion_seleccionada'];
          final geo = data['ubicacion_inicial'];
          final horaInicio = data['hora_aceptacion'] as Timestamp?;
          final horaFin = data['fecha_termino'] as Timestamp?;

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
                  (conductorSnapshot.data!['nombre'] ?? "Desconocido")
                      .toString()
                      .toUpperCase();

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

                  return Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 40),
                        const Text(
                          "Resumen del Viaje",
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text("\u{1F464} Cliente: $nombreCliente",
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        Text("\u{1F695} Conductor: $nombreConductor",
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        const Text("\u{1F4CD} Dirección de Recogida:",
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        Text("${geo.latitude}, ${geo.longitude}",
                            style: const TextStyle(fontSize: 16)),
                        const SizedBox(height: 10),
                        const Text("\u{1F3C1} Dirección de Destino:",
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        Text(direccionSeleccionada ?? "No disponible",
                            style: const TextStyle(fontSize: 16)),
                        const SizedBox(height: 10),
                        if (horaInicio != null)
                          Text(
                              "\u{1F552} Inicio: ${formatoHoraBogota(horaInicio)}"),
                        if (horaFin != null)
                          Text("\u{1F552} Fin: ${formatoHoraBogota(horaFin)}"),
                        if (horaInicio != null && horaFin != null)
                          Text(
                              "\u{23F1}\u{FE0F} Duración: ${obtenerDuracion(horaInicio, horaFin)}"),
                        if (_yaCalificada && _calificacion > 0) ...[
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _calificacion <= 2
                                    ? Icons.sentiment_very_dissatisfied
                                    : _calificacion == 3
                                        ? Icons.sentiment_neutral
                                        : Icons.sentiment_satisfied,
                                color: _calificacion <= 2
                                    ? Colors.red
                                    : _calificacion == 3
                                        ? Colors.orange
                                        : Colors.green,
                                size: 40,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                _calificacion <= 2
                                    ? "Mala experiencia"
                                    : _calificacion == 3
                                        ? "Aceptable"
                                        : "\u{1F389} ¡Muy buen servicio!",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: _calificacion <= 2
                                      ? Colors.red
                                      : _calificacion == 3
                                          ? Colors.orange
                                          : Colors.green,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const Spacer(),
                        if (!_yaCalificada) ...[
                          const Text("⭐ Califica tu experiencia:",
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 10),
                          RatingBar.builder(
                            initialRating: 0,
                            minRating: 1,
                            allowHalfRating: false,
                            direction: Axis.horizontal,
                            itemCount: 5,
                            itemBuilder: (context, _) =>
                                const Icon(Icons.star, color: Colors.amber),
                            onRatingUpdate: (rating) {
                              setState(() => _calificacion = rating);
                            },
                          ),
                          const SizedBox(height: 20),
                        ],
                        Center(
                          child: SizedBox(
                            width: MediaQuery.of(context).size.width * 0.8,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _yaCalificada || _calificacion == 0
                                  ? () {
                                      Navigator.pushReplacement(
                                          context,
                                          MaterialPageRoute(
                                              builder: (_) => const home()));
                                    }
                                  : () async {
                                      await _guardarCalificacion(
                                          data, nombreConductor, nombreCliente);
                                      Navigator.pushReplacement(
                                          context,
                                          MaterialPageRoute(
                                              builder: (_) => const home()));
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colores.amarillo,
                                foregroundColor: Colors.black,
                                textStyle: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(_yaCalificada
                                  ? "Volver al inicio"
                                  : "Calificar y volver"),
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),
                      ],
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

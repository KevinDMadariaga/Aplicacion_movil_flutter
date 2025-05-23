import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
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
  double _calificacion = 1.0; // Inicializado en 1 para que muestre estrella
  bool _yaCalificada = false;
  String _direccionRecogida = "Cargando dirección...";

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
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty && mounted) {
        final p = placemarks.first;
        setState(() {
          _direccionRecogida =
              "${p.street ?? ''}, ${p.locality ?? ''}, ${p.administrativeArea ?? ''}";
        });
      } else {
        setState(() {
          _direccionRecogida = "Dirección no disponible";
        });
      }
    } catch (e) {
      setState(() {
        _direccionRecogida = "Error al obtener dirección";
      });
    }
  }

  String _mapearCalificacionTexto(int calificacion) {
    switch (calificacion) {
      case 0:
        return "Mala experiencia";
      case 1:
        return "Malo";
      case 2:
        return "Regular";
      case 3:
        return "Bueno";
      case 4:
        return "Muy buen servicio";
      case 5:
        return "Excelente servicio";
      default:
        return "Sin calificación";
    }
  }

  Future<void> _guardarCalificacion(Map<String, dynamic> data,
      String nombreConductor, String nombreCliente) async {
    final horaInicio = data['hora_aceptacion'] as Timestamp?;
    final horaFin = data['fecha_terminacion'] as Timestamp?;
    final duracion = (horaInicio != null && horaFin != null)
        ? horaFin.toDate().difference(horaInicio.toDate()).inMinutes
        : 0;

    await FirebaseFirestore.instance
        .collection('historial viaje')
        .doc() // genera ID único
        .set({
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
          final horaFin = data['fecha_terminacion'] as Timestamp?;

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

                  return SafeArea(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Image.asset(
                              'assets/img/taxi.png',
                              height: 150,
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.person,
                                  size: 32, color: Color(0xFFFFD600)),
                              const SizedBox(width: 8),
                              Text(
                                nombreConductor,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),
                          Text(
                            "📍 Dirección de Recogida:",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            _direccionRecogida,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            "🏁 Dirección de Destino:",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            direccionSeleccionada ?? "No disponible",
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 20),
                          if (horaInicio != null) ...[
                            Text(
                              "🕓 Hora de Inicio:",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            Text(
                              formatoHoraBogota(horaInicio),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                          if (horaFin != null) ...[
                            Text(
                              "🕓 Hora de Finalización:",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            Text(
                              formatoHoraBogota(horaFin),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                          const SizedBox(height: 30),
                          if (!_yaCalificada) ...[
                            const Text(
                              "😊 Califica tu experiencia:",
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                GestureDetector(
                                  onTap: () =>
                                      setState(() => _calificacion = 1),
                                  child: Column(
                                    children: [
                                      Text(
                                        "😡",
                                        style: TextStyle(
                                          fontSize: 48,
                                          color: _calificacion == 1
                                              ? Colors.red
                                              : Colors.grey,
                                        ),
                                      ),
                                      Text("Malo",
                                          style: TextStyle(
                                            color: _calificacion == 1
                                                ? Colors.red
                                                : Colors.grey,
                                            fontWeight: _calificacion == 1
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                          )),
                                    ],
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () =>
                                      setState(() => _calificacion = 2),
                                  child: Column(
                                    children: [
                                      Text(
                                        "🙂",
                                        style: TextStyle(
                                          fontSize: 48,
                                          color: _calificacion == 2
                                              ? Colors.orange
                                              : Colors.grey,
                                        ),
                                      ),
                                      Text("Bueno",
                                          style: TextStyle(
                                            color: _calificacion == 2
                                                ? Colors.orange
                                                : Colors.grey,
                                            fontWeight: _calificacion == 2
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                          )),
                                    ],
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () =>
                                      setState(() => _calificacion = 3),
                                  child: Column(
                                    children: [
                                      Text(
                                        "😍",
                                        style: TextStyle(
                                          fontSize: 48,
                                          color: _calificacion == 3
                                              ? Colors.green
                                              : Colors.grey,
                                        ),
                                      ),
                                      Text("Excelente",
                                          style: TextStyle(
                                            color: _calificacion == 3
                                                ? Colors.green
                                                : Colors.grey,
                                            fontWeight: _calificacion == 3
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                          )),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                          ],
                          SizedBox(
                            width: MediaQuery.of(context).size.width * 0.8,
                            height: 50,
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
                                            "Por favor selecciona una calificación.")),
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFFD600),
                                foregroundColor: Colors.black,
                                textStyle: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                _yaCalificada
                                    ? "Volver al Mapa"
                                    : "Calificar y Volver",
                              ),
                            ),
                          ),
                          const SizedBox(height: 30),
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

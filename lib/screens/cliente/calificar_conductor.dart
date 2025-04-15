import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

class CalificarConductor extends StatefulWidget {
  final String solicitudId; // Recibimos el ID de la solicitud

  const CalificarConductor({Key? key, required this.solicitudId})
      : super(key: key);

  @override
  _CalificarConductorState createState() => _CalificarConductorState();
}

class _CalificarConductorState extends State<CalificarConductor> {
  double _calificacion = 0; // Calificación inicial de 0

  // Función para guardar la calificación en Firestore
  Future<void> _guardarCalificacion() async {
    try {
      // Obtener la referencia de la colección de calificaciones
      await FirebaseFirestore.instance.collection('calificaciones').add({
        'solicitudId': widget.solicitudId, // Guardamos el ID de la solicitud
        'calificacion': _calificacion, // Guardamos la calificación
        'timestamp':
            FieldValue.serverTimestamp(), // Guardamos la fecha de creación
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("¡Calificación guardada con éxito!")),
      );

      // Después de guardar la calificación, podemos navegar hacia otra página si lo deseas
      // Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => SomeOtherPage()));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error al guardar la calificación: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Calificar Conductor")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Por favor, califica al conductor",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            // RatingBar para calificar
            RatingBar.builder(
              initialRating: _calificacion,
              minRating: 1,
              direction: Axis.horizontal,
              allowHalfRating: true,
              itemCount: 5,
              itemSize: 40.0,
              itemPadding: const EdgeInsets.symmetric(horizontal: 4.0),
              itemBuilder: (context, _) => const Icon(
                Icons.star,
                color: Colors.amber,
              ),
              onRatingUpdate: (rating) {
                setState(() {
                  _calificacion = rating;
                });
              },
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _calificacion == 0
                  ? null // Deshabilitar si no se ha seleccionado calificación
                  : _guardarCalificacion,
              child: const Text("Guardar Calificación"),
            ),
          ],
        ),
      ),
    );
  }
}

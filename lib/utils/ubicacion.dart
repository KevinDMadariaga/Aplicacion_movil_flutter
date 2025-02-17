import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class GuardarUbicacion {
  /// Método para guardar la ubicación actual del usuario logueado en la colección especificada
  Future<void> guardarUbicacionUsuario(String coleccion) async {
    try {
      // Verificar si el usuario está autenticado
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw "No hay un usuario autenticado.";
      }

      // Verificar permisos de ubicación
      bool servicioHabilitado = await Geolocator.isLocationServiceEnabled();
      if (!servicioHabilitado) {
        throw "Los servicios de ubicación están deshabilitados.";
      }

      LocationPermission permisos = await Geolocator.checkPermission();
      if (permisos == LocationPermission.denied) {
        permisos = await Geolocator.requestPermission();
        if (permisos == LocationPermission.denied) {
          throw "Los permisos de ubicación fueron denegados.";
        }
      }

      if (permisos == LocationPermission.deniedForever) {
        throw "Los permisos de ubicación están denegados permanentemente.";
      }

      // Obtener ubicación actual
      final posicion = await Geolocator.getCurrentPosition(
        // ignore: deprecated_member_use
        desiredAccuracy: LocationAccuracy.high,
      );

      // Crear un GeoPoint para Firestore
      final geoPoint = GeoPoint(posicion.latitude, posicion.longitude);

      // Referencia al documento del usuario en la colección especificada
      final userDoc = FirebaseFirestore.instance.collection(coleccion).doc(user.uid);

      // Verificar si el documento existe
      final docSnapshot = await userDoc.get();
      if (docSnapshot.exists) {
        // Actualizar documento existente
        await userDoc.update({
          'ubicacion': geoPoint,
          'ultimaActualizacion': DateTime.now(),
        });
      } else {
        // Crear documento si no existe
        await userDoc.set({
          'ubicacion': geoPoint,
          'ultimaActualizacion': DateTime.now(),
          // Aquí puedes incluir otros datos básicos del usuario si es necesario
          'email': user.email,
        });
      }

      debugPrint("Ubicación guardada correctamente en la colección $coleccion.");
    } catch (e) {
      debugPrint("Error al guardar ubicación: $e");
      rethrow;
    }
  }
}


/*
Positioned(
  // Posiciona el botón dentro del Stack
  bottom: 20, // Margen inferior de 20 píxeles desde la parte inferior
  left: MediaQuery.of(context).size.width * 0.3, // Centrado horizontalmente
  child: ElevatedButton(
    // Define el estilo del botón
    style: ElevatedButton.styleFrom(
      backgroundColor: Colores.amarillo, // Color de fondo del botón
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20.0), // Bordes redondeados
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 32, // Relleno horizontal dentro del botón
        vertical: 12,   // Relleno vertical dentro del botón
      ),
    ),
    // Define la acción que se ejecuta al presionar el botón
    onPressed: () async {
      // Llama a la función que guarda la ubicación en Firestore
      await _guardarUbicacionAlIniciar('cliente'); // Colección 'cliente'
    },
    // Define el contenido del botón (texto)
    child: const Text(
      'Guardar Ubicación', // Texto que se muestra en el botón
      style: TextStyle(
        color: Colors.black, // Color del texto
        fontSize: 16,        // Tamaño de la fuente del texto
      ),
    ),
  ),
),
*/

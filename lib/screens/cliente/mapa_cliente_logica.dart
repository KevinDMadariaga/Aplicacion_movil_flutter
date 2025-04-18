import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_place/google_place.dart';
import 'package:taxi_app/components/boton.dart';
import 'package:taxi_app/components/colores.dart';
import 'package:taxi_app/services/api_google.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class UbicacionResultado {
  final LatLng? location;
  final String direccion;
  final String error;
  UbicacionResultado({this.location, this.direccion = '', this.error = ''});
}

Future<UbicacionResultado> obtenerUbicacionUsuario() async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return UbicacionResultado(
          error: "Los servicios de ubicación están deshabilitados.");
    }

    LocationPermission permisos = await Geolocator.checkPermission();
    if (permisos == LocationPermission.denied) {
      permisos = await Geolocator.requestPermission();
    }
    if (permisos == LocationPermission.deniedForever) {
      return UbicacionResultado(
          error: "Permisos de ubicación denegados permanentemente.");
    }

    Position posicion = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    LatLng userLocation = LatLng(posicion.latitude, posicion.longitude);

    List<Placemark> placemarks =
        await placemarkFromCoordinates(posicion.latitude, posicion.longitude);
    String direccion = "Dirección desconocida";
    if (placemarks.isNotEmpty) {
      final place = placemarks.first;
      direccion = [
        place.street,
        place.locality,
        place.administrativeArea,
        place.country
      ].where((e) => e != null && e!.isNotEmpty).map((e) => e!).join(", ");
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('cliente').doc(user.uid).set(
        {
          'ubicacion': GeoPoint(posicion.latitude, posicion.longitude),
          'ultima_actualizacion': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }

    return UbicacionResultado(location: userLocation, direccion: direccion);
  } catch (e) {
    return UbicacionResultado(error: 'Error al obtener ubicación: $e');
  }
}

LatLngBounds crearLimitesMapa(LatLng a, LatLng b) {
  return LatLngBounds(
    southwest: LatLng(
      a.latitude < b.latitude ? a.latitude : b.latitude,
      a.longitude < b.longitude ? a.longitude : b.longitude,
    ),
    northeast: LatLng(
      a.latitude > b.latitude ? a.latitude : b.latitude,
      a.longitude > b.longitude ? a.longitude : b.longitude,
    ),
  );
}

Marker crearMarkerSeleccionado(UbicacionResultado result) {
  return Marker(
    markerId: const MarkerId("ubicacion_seleccionada"),
    position: result.location!,
    infoWindow: InfoWindow(title: "Destino", snippet: result.direccion),
  );
}

Polyline crearRutaPolyline(LatLng origen, LatLng destino) {
  return Polyline(
    polylineId: const PolylineId('ruta'),
    points: [origen, destino],
    color: const Color.fromARGB(255, 0, 0, 0),
    width: 4,
  );
}

Widget crearDrawerUsuario(User? user, BuildContext context) {
  return Drawer(
    child: ListView(
      padding: EdgeInsets.zero,
      children: <Widget>[
        DrawerHeader(
          decoration: BoxDecoration(color: Colores.amarillo),
          child: Text(
            'Bienvenido, ${user?.email ?? 'Usuario'}',
            style: const TextStyle(
                color: Colors.black, fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.logout),
          title: const Text('Cerrar Sesión'),
          onTap: () async {
            await FirebaseAuth.instance.signOut();
            Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
          },
        ),
      ],
    ),
  );
}

Widget crearDialogoCarga(BuildContext context, VoidCallback onCancelar) {
  return AlertDialog(
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 15),
        const Text("Buscando conductor..."),
        const SizedBox(height: 10),
        CustomButton(
          text: "Cancelar",
          onPressed: () {
            Navigator.of(context, rootNavigator: true).pop(); // 🔴 Cierra el diálogo
            onCancelar(); // 🟢 Ejecuta la lógica de cancelación adicional
          },
          width: 130,
          height: 50,
          fontSize: 16,
        ),
      ],
    ),
  );
}


Widget posicionarInfoUbicacion(
  String direccionInicial,
  String direccionSeleccionada, {
  required VoidCallback onCancelar,
  required VoidCallback onAceptar,
}) {
  return Positioned(
    bottom: 20,
    left: 16,
    right: 16,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.location_on, color: Colors.blueAccent),
              SizedBox(width: 8),
              Text(
                "Ubicación Inicial",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(direccionInicial),
          const Divider(height: 20, thickness: 1.2),
          Row(
            children: const [
              Icon(Icons.flag, color: Colors.green),
              SizedBox(width: 8),
              Text(
                "Ubicación Seleccionada",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            direccionSeleccionada.isNotEmpty
                ? direccionSeleccionada
                : "No se ha seleccionado una ubicación",
            style: const TextStyle(fontSize: 14, color: Colors.black87),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              CustomButton(
                text: 'Cancelar',
                onPressed: onCancelar,
                width: 130,
                height: 50,
                fontSize: 16,
              ),
              CustomButton(
                text: 'Aceptar',
                onPressed: onAceptar,
                width: 130,
                height: 50,
                fontSize: 16,
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

Future<String?> crearSolicitudFirebase(
    LatLng origen, LatLng destino, String direccion) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return null;

  final ref = await FirebaseFirestore.instance.collection('solicitud').add({
    'clienteId': user.uid,
    'ubicacion_inicial': GeoPoint(origen.latitude, origen.longitude),
    'ubicacion_seleccionada': GeoPoint(destino.latitude, destino.longitude),
    'direccion_seleccionada': direccion,
    'estado': 'pendiente',
    'timestamp': FieldValue.serverTimestamp(),
  });

  return ref.id;
}

Future<UbicacionResultado?> mostrarBusquedaUbicacion({
  required BuildContext context,
  required GooglePlace googlePlace,
  required LatLng? userLocation,
}) async {
  List<AutocompletePrediction> predictions = [];
  final controller = TextEditingController();

  return await showModalBottomSheet<UbicacionResultado>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
    ),
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          void buscar(String input) async {
            if (input.isEmpty) return;
            final result = await googlePlace.autocomplete.get(
              input,
              location: userLocation != null
                  ? LatLon(userLocation.latitude, userLocation.longitude)
                  : null,
              radius: 10000,
              strictbounds: true,
              components: [Component("country", "co")],
            );
            setModalState(() => predictions = result?.predictions ?? []);
          }

          return SafeArea(
            child: Stack(
              children: [
                Padding(
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 40,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.place,
                          size: 40, color: Colors.blueAccent),
                      const SizedBox(height: 8),
                      const Text(
                        '¿A dónde quieres ir?',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: controller,
                        autofocus: true,
                        onChanged: buscar,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white,
                          hintText: "Buscar dirección...",
                          prefixIcon: const Icon(Icons.search,
                              color: Colors.blueAccent),
                          focusedBorder: OutlineInputBorder(
                            borderSide: const BorderSide(
                                color: Colors.blueAccent, width: 2.0),
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: const BorderSide(
                                color: Colors.grey, width: 1.0),
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (predictions.isNotEmpty)
                        Flexible(
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: predictions.length,
                            itemBuilder: (context, index) {
                              final p = predictions[index];
                              return ListTile(
                                leading: const Icon(Icons.location_on,
                                    color: Colors.blue),
                                title: Text(p.description ?? ""),
                                onTap: () async {
                                  final details =
                                      await googlePlace.details.get(p.placeId!);
                                  if (details?.result?.geometry?.location !=
                                      null) {
                                    final l =
                                        details!.result!.geometry!.location!;
                                    final dir =
                                        details.result!.formattedAddress ??
                                            "Dirección desconocida";
                                    Navigator.pop(
                                      context,
                                      UbicacionResultado(
                                        location: LatLng(l.lat!, l.lng!),
                                        direccion: dir,
                                      ),
                                    );
                                  }
                                },
                              );
                            },
                          ),
                        ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
                // Botón de cerrar con estilo moderno
                Positioned(
                  top: 40,
                  right: 12,
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.grey
                        .shade200, // Puedes cambiarlo a Colors.black si prefieres oscuro
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.black),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

Future<List<LatLng>> obtenerRutaPorCalles(LatLng origen, LatLng destino) async {
  final apiKey = ApiConfig.getGoogleMapsApiKey();
  final url = Uri.parse(
    'https://maps.googleapis.com/maps/api/directions/json'
    '?origin=${origen.latitude},${origen.longitude}'
    '&destination=${destino.latitude},${destino.longitude}'
    '&mode=driving'
    '&key=$apiKey',
  );

  final response = await http.get(url);

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    if (data['routes'].isNotEmpty) {
      final polyline = data['routes'][0]['overview_polyline']['points'];
      return decodePolyline(polyline);
    } else {
      print('❌ No se encontraron rutas entre los puntos.');
    }
  } else {
    print('❌ Error al consultar Google Directions API: ${response.statusCode}');
  }

  return [];
}

List<LatLng> decodePolyline(String polyline) {
  List<LatLng> points = [];
  int index = 0, len = polyline.length;
  int lat = 0, lng = 0;

  while (index < len) {
    int b, shift = 0, result = 0;
    do {
      b = polyline.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    int dlat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
    lat += dlat;

    shift = 0;
    result = 0;
    do {
      b = polyline.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    int dlng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
    lng += dlng;

    points.add(LatLng(lat / 1e5, lng / 1e5));
  }

  return points;
}

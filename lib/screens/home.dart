import 'package:flutter/material.dart';
import 'package:taxi_app/components/colores.dart';
import 'package:taxi_app/screens/cliente/login_cliente.dart';

// ignore: camel_case_types
class home extends StatelessWidget {
  const home({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    // Dimensiones de la pantalla
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment:
                MainAxisAlignment.center, // Centra en el eje vertical
            children: [
              Image.asset(
                'assets/img/taxi.png', // Ruta de la imagen del logo (configura correctamente en pubspec.yaml)
                height: screenHeight * 0.25, // 25% de la altura de la pantalla
              ),
              SizedBox(
                  height: screenHeight *
                      0.15), // Espacio entre la imagen y los botones
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: screenWidth *
                      0.25, // 20% del ancho como padding horizontal
                  vertical:
                      screenHeight * 0.01, // 2% del alto como padding vertical
                ),
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) =>
                              LoginCliente()), // Cambia PaginaDestino por el nombre de tu widget
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colores.amarillo, // Color de fondo
                    foregroundColor: Colores.negro, // Color del texto
                    padding: EdgeInsets.symmetric(
                      vertical: screenHeight * 0.01,
                    ), // Altura del botón
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(30.0), // Bordes redondeados
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment:
                        MainAxisAlignment.center, // Centra el contenido
                    children: [
                      Image.asset(
                        'assets/img/user.png', // Ruta de la imagen (asegúrate de incluirla en `pubspec.yaml`)
                        height: screenHeight * 0.08,
                      ),
                      SizedBox(
                          width: screenWidth *
                              0.03), // Espaciado entre la imagen y el texto
                      Text(
                        "Clientes",
                        style: TextStyle(
                            fontSize: screenWidth * 0.05), // Tamaño del texto
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: screenWidth * 0.25,
                  vertical: screenHeight * 0.01,
                ),
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) =>
                              LoginCliente()), // Cambia PaginaDestino por el nombre de tu widget
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colores.amarillo, // Color de fondo
                    foregroundColor: Colores.negro, // Color del texto
                    padding: EdgeInsets.symmetric(
                      vertical: screenHeight * 0.01,
                    ), // Altura del botón
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(30.0), // Bordes redondeados
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment:
                        MainAxisAlignment.center, // Centra el contenido
                    children: [
                      Image.asset(
                          'assets/img/driver.png', // Ruta de la imagen (asegúrate de incluirla en `pubspec.yaml`)
                          height: screenHeight * 0.08),
                      SizedBox(
                          width: screenWidth *
                              0.03), // Espaciado entre la imagen y el texto
                      Text(
                        "Conductor",
                        style: TextStyle(
                            fontSize: screenWidth * 0.05), // Tamaño del texto
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:taxi_app/components/colores.dart';
import 'package:taxi_app/screens/cliente/login_cliente.dart';
import 'package:taxi_app/screens/conductor/inicio_sesion/login_conductor.dart';

class Home extends StatelessWidget {
  const Home({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final height = constraints.maxHeight;

            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/img/taxi.png',
                    height: height * 0.30,
                  ),
                  SizedBox(height: height * 0.12),

                  // Botón Clientes
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: width * 0.2,
                      vertical: height * 0.01,
                    ),
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const LoginCliente()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colores.amarillo,
                        foregroundColor: Colores.negro,
                        padding: EdgeInsets.symmetric(
                          vertical: height * 0.02,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30.0),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(
                            'assets/img/user.png',
                            height: height * 0.07,
                          ),
                          SizedBox(width: width * 0.03),
                          Text(
                            "Clientes",
                            style: TextStyle(
                              fontSize: width * 0.055,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Botón Conductor
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: width * 0.2,
                      vertical: height * 0.01,
                    ),
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const LoginConductor()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colores.amarillo,
                        foregroundColor: Colores.negro,
                        padding: EdgeInsets.symmetric(
                          vertical: height * 0.02,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30.0),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(
                            'assets/img/driver.png',
                            height: height * 0.07,
                          ),
                          SizedBox(width: width * 0.03),
                          Text(
                            "Conductor",
                            style: TextStyle(
                              fontSize: width * 0.055,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

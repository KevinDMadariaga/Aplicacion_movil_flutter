import 'package:flutter/material.dart';
import 'package:taxi_app/registro.dart';



class RegistroCliente extends StatelessWidget {
  const RegistroCliente({super.key});

  @override
  Widget build(BuildContext context) {
    return RegistroFormulario(userType: 'cliente'); // Pasa 'cliente'
  }
}

import 'package:flutter/material.dart';
import 'package:taxi_app/registro.dart';



class RegistroConductor extends StatelessWidget {
  const RegistroConductor({super.key});

  @override
  Widget build(BuildContext context) {
    return RegistroFormulario(userType: 'conductor'); // Pasa 'conductor'
  }
}

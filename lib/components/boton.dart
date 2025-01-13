import 'package:flutter/material.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final double? width;
  final double? height;
  final double? fontSize;
  final Widget? icon; // Ícono como widget opcional

  const CustomButton({super.key, 
    required this.text,
    required this.onPressed,
    this.width,
    this.height,
    this.fontSize,
    this.icon, // Ícono personalizado
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final buttonWidth = width ?? screenWidth * 0.8;
    final buttonHeight = height ?? screenHeight * 0.07;
    final textFontSize = fontSize ?? buttonHeight * 0.4;

    // ignore: sized_box_for_whitespace
    return Container(
      width: buttonWidth,
      height: buttonHeight,
      child: ElevatedButton(
        onPressed: onPressed,
        // ignore: sort_child_properties_last
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              icon!, // Agrega el ícono proporcionado
              SizedBox(width: 8), // Espacio entre ícono y texto
            ],
            Text(
              text,
              style: TextStyle(
                color: Colors.white,
                fontSize: textFontSize,
              ),
            ),
          ],
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.yellow[700],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
      ),
    );
  }
}

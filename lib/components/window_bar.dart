// lib/widgets/custom_window_bar.dart
import 'package:flutter/material.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';

class CustomWindowBar extends StatelessWidget {
  const CustomWindowBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color.fromRGBO(31, 31, 35, 1), // Fondo del título
      height: 45,
      child: WindowTitleBarBox(
        child: Row(
          children: [
            Expanded(
              child: MoveWindow(
                child: Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.center, // Centra verticalmente
                  children: [
                    const SizedBox(width: 12),
                    Image.asset(
                      'lib/imagenes/logoPharmaSalud.png',
                      width: 30,
                      height: 30,
                    ),
                    const SizedBox(width: 15),
                    const Text(
                      "Sistema de Farmacia",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const WindowButtons(),
          ],
        ),
      ),
    );
  }
}

class WindowButtons extends StatelessWidget {
  const WindowButtons({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MinimizeWindowButton(colors: buttonColors),
        MaximizeWindowButton(colors: buttonColors),
        CloseWindowButton(colors: closeButtonColors),
      ],
    );
  }
}

final buttonColors = WindowButtonColors(
  iconNormal: Colors.white,
  mouseOver: const Color.fromARGB(255, 102, 96, 96),
  mouseDown: const Color.fromARGB(255, 140, 130, 140),
  iconMouseOver: Colors.white,
  iconMouseDown: Colors.white,
);

final closeButtonColors = WindowButtonColors(
  mouseOver: Colors.red,
  mouseDown: Colors.redAccent,
  iconNormal: Colors.white,
  iconMouseOver: Colors.white,
);

import 'package:flutter/material.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:pharma_salud/components/window_bar.dart';

class MainLayout extends StatelessWidget {
  final Widget child;

  const MainLayout({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return WindowBorder(
      color: const Color.fromARGB(255, 0, 0, 0),
      width: 0,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              const CustomWindowBar(),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

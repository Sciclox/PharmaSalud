import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class KeyFocusWrapper extends StatefulWidget {
  final Map<LogicalKeyboardKey, FocusNode> bindings;
  final Map<LogicalKeyboardKey, VoidCallback>? actions;
  final Widget child;

  const KeyFocusWrapper({
    super.key,
    required this.bindings,
    required this.child,
    this.actions,
  });

  @override
  State<KeyFocusWrapper> createState() => _KeyFocusWrapperState();
}

class _KeyFocusWrapperState extends State<KeyFocusWrapper> {
  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  bool _onKey(KeyEvent event) {
    if (event is KeyDownEvent) {
      final node = widget.bindings[event.logicalKey];
      if (node != null && node.canRequestFocus && node.context != null) {
        node.requestFocus();
        return true;
      }
      final action = widget.actions?[event.logicalKey];
      if (action != null) {
        action();
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class F1Badge extends StatelessWidget {
  final String label;
  final Color? color;
  const F1Badge({super.key, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? const Color(0xFF1D1D1F);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: c.withOpacity(0.06),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: c.withOpacity(0.12)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: c.withOpacity(0.5),
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

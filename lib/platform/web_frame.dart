import 'package:flutter/material.dart';

class WebFrame extends StatelessWidget {
  const WebFrame({super.key, required this.child});

  final Widget child;

  static const double maxContentWidth = 720;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    if (mq.size.width <= maxContentWidth) return child;

    return ColoredBox(
      color: const Color(0xFFE3EAF2),
      child: Center(
        child: SizedBox(
          width: maxContentWidth,
          height: mq.size.height,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 24,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: ClipRect(
              child: MediaQuery(
                data: mq.copyWith(
                  size: Size(maxContentWidth, mq.size.height),
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

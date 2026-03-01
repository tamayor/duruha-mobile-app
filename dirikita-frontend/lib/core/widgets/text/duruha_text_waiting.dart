import 'package:flutter/material.dart';

class DuruhaWaitingText extends StatefulWidget {
  const DuruhaWaitingText({super.key});

  @override
  State<DuruhaWaitingText> createState() => _DuruhaWaitingTextState();
}

class _DuruhaWaitingTextState extends State<DuruhaWaitingText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  int _dotCount = 0;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 1500),
        )..addListener(() {
          final newDotCount = (_controller.value * 4).floor() % 4;
          if (newDotCount != _dotCount) {
            setState(() => _dotCount = newDotCount);
          }
        });
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      'waiting${'.' * _dotCount}',
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        fontStyle: FontStyle.italic,
        color: Theme.of(context).colorScheme.onSecondary,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

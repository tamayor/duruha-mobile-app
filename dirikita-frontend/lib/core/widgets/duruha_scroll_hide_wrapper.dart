import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class DuruhaScrollHideWrapper extends StatefulWidget {
  final Widget bar;
  final Widget body;
  final double hideHeight;
  final Duration duration;

  const DuruhaScrollHideWrapper({
    super.key,
    required this.bar,
    required this.body,
    this.hideHeight = 48,
    this.duration = const Duration(milliseconds: 300),
  });

  @override
  State<DuruhaScrollHideWrapper> createState() =>
      _DuruhaScrollHideWrapperState();
}

class _DuruhaScrollHideWrapperState extends State<DuruhaScrollHideWrapper> {
  bool _isVisible = true;

  @override
  Widget build(BuildContext context) {
    return NotificationListener<Notification>(
      onNotification: (notification) {
        if (notification is UserScrollNotification) {
          if (notification.direction == ScrollDirection.forward &&
              !_isVisible) {
            setState(() => _isVisible = true);
          } else if (notification.direction == ScrollDirection.reverse &&
              _isVisible) {
            setState(() => _isVisible = false);
          }
        }
        return false;
      },
      child: Column(
        children: [
          AnimatedContainer(
            duration: widget.duration,
            height: _isVisible ? widget.hideHeight : 0,
            curve: Curves.easeInOut,
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: SizedBox(height: widget.hideHeight, child: widget.bar),
            ),
          ),
          Expanded(child: widget.body),
        ],
      ),
    );
  }
}

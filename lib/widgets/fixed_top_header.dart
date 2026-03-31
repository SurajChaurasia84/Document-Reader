import 'package:flutter/material.dart';

class FixedTopHeader extends StatelessWidget {
  const FixedTopHeader({
    super.key,
    required this.title,
    this.trailing,
    this.horizontalPadding = 12,
    this.topPadding = 10,
  });

  final String title;
  final Widget? trailing;
  final double horizontalPadding;
  final double topPadding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        topPadding,
        horizontalPadding,
        0,
      ),
      child: Container(
        width: double.infinity,
        height: 52,
        color: const Color(0xFF0A0E1A),
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
            SizedBox(
              width: 48,
              height: 40,
              child: Center(child: trailing ?? const SizedBox.shrink()),
            ),
          ],
        ),
      ),
    );
  }
}

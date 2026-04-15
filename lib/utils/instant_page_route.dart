import 'package:flutter/material.dart';

class InstantPageRoute<T> extends PageRouteBuilder<T> {
  InstantPageRoute({
    required WidgetBuilder builder,
    super.settings,
  }) : super(
         transitionDuration: Duration.zero,
         reverseTransitionDuration: Duration.zero,
         pageBuilder: (context, animation, secondaryAnimation) =>
             builder(context),
         transitionsBuilder:
             (context, animation, secondaryAnimation, child) => child,
       );
}

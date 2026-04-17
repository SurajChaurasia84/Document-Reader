import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/app_controller.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.child});

  final Widget child;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const _minimumSplash = Duration(milliseconds: 650);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  )..forward();

  late final Animation<double> _logoScale = Tween<double>(
    begin: 0.92,
    end: 1,
  ).animate(
    CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
  );

  late final Future<void> _holdFuture = Future<void>.delayed(_minimumSplash);
  bool _ready = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncReadyState();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _syncReadyState() async {
    final appController = context.read<AppController>();
    if (!appController.isInitialized || _ready) {
      return;
    }

    await _holdFuture;
    if (!mounted) {
      return;
    }

    setState(() {
      _ready = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final appController = context.watch<AppController>();
    if (appController.isInitialized && !_ready) {
      unawaited(_syncReadyState());
    }

    if (_ready) {
      return widget.child;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF0A0E1A), Color(0xFF101726)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ScaleTransition(
                scale: _logoScale,
                child: FadeTransition(
                  opacity: _controller,
                  child: Container(
                    width: 98,
                    height: 98,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: const EdgeInsets.all(18),
                    child: Image.asset('assets/splash.png', fit: BoxFit.contain),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              FadeTransition(
                opacity: _controller,
                child: const Text(
                  'PDF Studio',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: 140,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                child: Column(
                  children: [
                    LinearProgressIndicator(
                      minHeight: 2.2,
                      backgroundColor: Colors.white.withValues(alpha: 0.1),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.white.withValues(alpha: 0.72),
                      ),
                    ),
                    if (appController.statusMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        appController.statusMessage!,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ],
                  ],
                ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

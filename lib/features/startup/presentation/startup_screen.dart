// Shows the lightweight branded screen while session startup is being resolved.

import 'package:flutter/material.dart';

import '../../../app/theme/mento_colors.dart';

class StartupScreen extends StatelessWidget {
  const StartupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.35),
            radius: 1.2,
            colors: [MentoColors.deepIndigo, MentoColors.midnight],
          ),
        ),
        child: Center(
          child: Semantics(
            label: 'Mento is starting',
            liveRegion: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/images/mento_logo.png',
                  width: 124,
                  height: 124,
                ),
                const SizedBox(height: 24),
                const Text(
                  'MENTO',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: 24),
                const SizedBox.square(
                  dimension: 24,
                  child: CircularProgressIndicator(
                    color: MentoColors.cyan,
                    strokeWidth: 2.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

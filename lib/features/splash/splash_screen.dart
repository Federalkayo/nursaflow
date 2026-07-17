import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';

/// Shown only for the brief moment between app start and the first
/// `authStateChanges()` event, while the router doesn't yet know whether
/// there's a signed-in user. Never reachable once auth state is known —
/// the router redirect always bounces away from here.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _scale = Tween<double>(begin: 0.92, end: 1.06).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _opacity = Tween<double>(begin: 0.75, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Opacity(
                  opacity: _opacity.value,
                  child: Transform.scale(
                    scale: _scale.value,
                    child: child,
                  ),
                );
              },
              child: Container(
                width: 110,
                height: 110,
                alignment: Alignment.center,
                // TEMP DEBUG: a visible box behind the logo. If you can see
                // this pink square's edges but not the artwork inside it,
                // the PNG itself is white/transparent and blending into the
                // background — not a loading problem. Remove once confirmed.
                decoration: BoxDecoration(
                  color: Colors.pinkAccent.withOpacity(0.15),
                  border: Border.all(color: Colors.pinkAccent, width: 1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Image.asset(
                  'assets/images/logo.png',
                  width: 96,
                  height: 96,
                  errorBuilder: (context, error, stackTrace) {
                    // Keeps the layout (and the pulse animation) intact even
                    // if the asset is missing or hasn't been picked up yet —
                    // remove this once logo.png is confirmed loading.
                    return Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(Icons.medical_services,
                          color: Colors.white, size: 44),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text('NursaFlow',
                style: AppTextStyles.headlineLg(color: AppColors.primary)),
          ],
        ),
      ),
    );
  }
}
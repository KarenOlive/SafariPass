import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'main_layout.dart';
import 'phone_auth_screen.dart';
import 'dart:math' as math;
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:ui';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final Color _kBackgroundColor = const Color(0xFF1A237E);
  final Color _kOrangeGlow = const Color(0xFFFF6D00);

  @override
  void initState() {
    super.initState();
    _navigateToHome();
  }

  _navigateToHome() async {
    // Simulate a loading delay (e.g., checking local SQLite)
    await Future.delayed(const Duration(milliseconds: 3000));
    
    if (!mounted) return;

    // Check if user is already signed in with Firebase
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // Not signed in – go to phone auth screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const PhoneAuthScreen()),
      );
    } else {
      // Already signed in – go directly to main layout
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MainLayout()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBackgroundColor,
      body: Stack(
        children: [
          _buildBackgroundDecorations(),
          SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 2),
                  _buildGlassIcon(),
                  const SizedBox(height: 40),
                  const Text(
                    "SafariPass",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Your journey, simplified",
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 60),
                  const BouncingDotsLoader(),
                  const Spacer(flex: 2),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20.0),
                    child: Text(
                      "Powered by Gemini AI",
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // This creates the subtle blurred blobs in the background
  Widget _buildBackgroundDecorations() {
    return Stack(
      children: [
        Positioned(
          top: -50,
          left: -50,
          child: _blurBlob(200, Colors.blueAccent.withValues(alpha: 0.2)),
        ),
        Positioned(
          bottom: 100,
          right: -80,
          child: _blurBlob(250, _kOrangeGlow.withValues(alpha: 0.15)),
        ),
        Positioned(
          top: 200,
          right: -30,
          child: _blurBlob(150, Colors.white.withValues(alpha: 0.05)),
        ),
      ],
    );
  }

  Widget _blurBlob(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
        child: Container(color: Colors.transparent),
      ),
    );
  }

  Widget _buildGlassIcon() {
    // We use a Stack to layer the glow BEHIND the glass container
    return Stack(
      alignment: Alignment.center,
      children: [
        // Layer 1: The Orange Glow
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _kOrangeGlow.withValues(alpha: 0.4),
            boxShadow: [
              BoxShadow(
                color: _kOrangeGlow.withValues(alpha: 0.6),
                blurRadius: 60,
                spreadRadius: 10,
              ),
            ],
          ),
        ),

        // Layer 2: The Glass Container
        // Glassmorphism relies on a semi-transparent gradient and a border
        Container(
          width: 130,
          height: 130,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            // Subtle gradient for the "glass" fill
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.7),
                Colors.white.withValues(alpha: 0.05),
              ],
            ),
            // The thin, brighter border defines the glass edge
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: Center(
            // Changed from SvgPicture to Image.asset
            child: Image.asset(
              'assets/passport.png',
              width: 64,
              height: 64,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ],
    );
  }
}

// ==========================================
// Custom Widget: Bouncing Dots Loader
// ==========================================
class BouncingDotsLoader extends StatefulWidget {
  const BouncingDotsLoader({super.key});

  @override
  State<BouncingDotsLoader> createState() => _BouncingDotsLoaderState();
}

class _BouncingDotsLoaderState extends State<BouncingDotsLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 60,
      height: 20,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildDot(0.0),
              _buildDot(0.2),
              _buildDot(0.4),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDot(double delay) {
    final double animationValue = (_controller.value + delay) % 1.0;
    final double offset = math.sin(animationValue * math.pi * 2) * 6;
    return Transform.translate(
      offset: Offset(0, -offset.abs()),
      child: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.7),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
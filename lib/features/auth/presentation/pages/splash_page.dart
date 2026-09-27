import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../../../../config/router/role_nav_config.dart';
import '../../../../config/router/route_paths.dart';
import '../../../patient/domain/entities/patient_profile.dart';
import '../../../patient/presentation/providers/patient_providers.dart';
import '../../domain/entities/user_role.dart';
import '../providers/auth_providers.dart';
import '../state/auth_state.dart';

/// P1 — Welcome / Splash.
/// Plays full-screen video on Mobile (with role-specific videos for Doctor/Assistant),
/// and shows a clean, centered brand logo on Web.
class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage> {
  VideoPlayerController? _controller;
  bool _isVideoInitialized = false;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    _startSplash();
  }

  Future<void> _startSplash() async {
    // On Web: show clean logo with brand delay, avoiding portrait video distortion
    if (kIsWeb) {
      await Future.delayed(const Duration(milliseconds: 1000));
      _navigateNext();
      return;
    }

    // On Mobile: brief window (up to 300ms) to allow session restore to settle
    // so we can play the Doctor or Clinic Assistant video if already logged in.
    final deadline = DateTime.now().add(const Duration(milliseconds: 300));
    while (mounted &&
        ref.read(authControllerProvider) is AuthLoading &&
        DateTime.now().isBefore(deadline)) {
      await Future.delayed(const Duration(milliseconds: 25));
    }
    if (!mounted) return;

    final authState = ref.read(authControllerProvider);
    final user = authState is AuthAuthenticated ? authState.user : null;

    // Pick role-specific video if available
    String videoAsset = 'assets/videos/splash.mp4';
    if (user != null) {
      if (user.role == UserRole.doctor) {
        videoAsset = 'assets/videos/doctor_splash.mp4';
      } else if (user.role == UserRole.pharmacist) {
        videoAsset = 'assets/videos/assistant_splash.mp4';
      }
    }

    VideoPlayerController? controller;
    try {
      debugPrint('🎬 [Splash] Loading video: $videoAsset');
      controller = VideoPlayerController.asset(videoAsset);
      await controller.initialize();
      debugPrint('🎬 [Splash] Video initialized: $videoAsset (Duration: ${controller.value.duration})');
    } catch (e) {
      debugPrint('❌ [Splash] Failed to load $videoAsset: $e');
      if (videoAsset != 'assets/videos/splash.mp4') {
        try {
          debugPrint('🎬 [Splash] Falling back to assets/videos/splash.mp4');
          controller = VideoPlayerController.asset('assets/videos/splash.mp4');
          await controller.initialize();
        } catch (e2) {
          debugPrint('❌ [Splash] Failed to load fallback video: $e2');
          controller = null;
        }
      } else {
        controller = null;
      }
    }

    if (controller != null && mounted) {
      _controller = controller;
      controller.setVolume(0.0);
      controller.setLooping(false);

      controller.addListener(() {
        if (!mounted || _hasNavigated) return;
        final position = controller!.value.position;
        final duration = controller.value.duration;
        if (duration > Duration.zero && position >= duration) {
          _navigateNext();
        }
      });

      setState(() {
        _isVideoInitialized = true;
      });
      await controller.play();
    } else {
      // Fallback if video is unavailable or in unit tests
      await Future.delayed(const Duration(milliseconds: 900));
      _navigateNext();
    }
  }

  Future<void> _navigateNext() async {
    if (_hasNavigated || !mounted) return;
    _hasNavigated = true;

    // The session restore may still be running.
    final deadline = DateTime.now().add(const Duration(seconds: 8));
    while (mounted &&
        ref.read(authControllerProvider) is AuthLoading &&
        DateTime.now().isBefore(deadline)) {
      await Future.delayed(const Duration(milliseconds: 50));
    }
    if (!mounted) return;

    final authState = ref.read(authControllerProvider);
    if (authState is! AuthAuthenticated) {
      context.go(RoutePaths.login);
      return;
    }
    final user = authState.user;
    if (user.mustChangePassword) {
      context.go(RoutePaths.forcePasswordChange);
      return;
    }

    if (user.role.name == 'patient') {
      var settled = false;
      var failed = false;
      PatientProfile? profile;
      final settleDeadline = DateTime.now().add(const Duration(seconds: 8));
      while (mounted && !settled && DateTime.now().isBefore(settleDeadline)) {
        final profileAsync = ref.read(patientProfileProvider(user.id));
        if (profileAsync is AsyncError) {
          failed = true;
          break;
        }
        if (profileAsync is AsyncLoading) {
          await Future.delayed(const Duration(milliseconds: 50));
          continue;
        }
        profile = profileAsync.valueOrNull;
        settled = true;
      }
      if (!mounted) return;
      if (failed || !settled) {
        context.go(RoutePaths.login);
        return;
      }
      if (profile == null) {
        context.go(RoutePaths.onboardingWellnessGoals);
        return;
      }
    }
    context.go(kRoleNavConfig[user.role]!.rootPath);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // On Web or fallback: show a clean, centered, animated brand logo
    if (kIsWeb || !_isVideoInitialized || _controller == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Image.asset(
            'assets/images/logo.png',
            width: 250,
          )
          .animate()
          .fadeIn(duration: 400.ms, curve: Curves.easeOut)
          .scaleXY(begin: 0.92, end: 1.0, duration: 400.ms, curve: Curves.easeOutBack),
        ),
      );
    }

    // On Mobile: fill the entire phone screen seamlessly with the video
    return Scaffold(
      backgroundColor: Colors.white,
      body: SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: _controller!.value.size.width,
            height: _controller!.value.size.height,
            child: VideoPlayer(_controller!),
          ),
        ),
      ),
    );
  }
}

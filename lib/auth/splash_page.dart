import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_page.dart';
import '../theme.dart';
import '../database/database_helper.dart';
import '../pages/motor_setup_page.dart';
import '../pages/navbar.dart';
import '../services/supabase_service.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  Timer? _watchdogTimer;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeApp();
    });
  }

  @override
  void dispose() {
    _watchdogTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    void safeNavigate(Widget destination) {
      if (_hasNavigated || !mounted) return;
      _hasNavigated = true;
      _watchdogTimer?.cancel();
      try {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => destination),
        );
      } catch (e) {
        debugPrint('Navigation error: $e');
      }
    }

    _watchdogTimer = Timer(const Duration(seconds: 5), () {
      if (!_hasNavigated && mounted) {
        debugPrint('Watchdog: Force navigating to login (timeout)');
        safeNavigate(const LoginPage());
      }
    });

    try {
      await dotenv.load(fileName: ".env").timeout(
        const Duration(milliseconds: 500),
        onTimeout: () {
          debugPrint('.env load timeout - continuing without it');
        },
      ).catchError((e) {
        debugPrint('dotenv load error: $e');
      });

      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]).catchError((e) {
        debugPrint('Orientation error: $e');
      });

      await Future.delayed(const Duration(milliseconds: 800));

      if (!mounted || _hasNavigated) return;

      final supabaseInitFuture = _initializeSupabase();

      await Future.delayed(const Duration(milliseconds: 500));

      final supabaseInitialized = await supabaseInitFuture;
      bool hasSession = false;

      if (supabaseInitialized) {
        try {
          final supabaseService = SupabaseService();
          hasSession = supabaseService.isInitialized && supabaseService.currentUser != null;
        } catch (e) {
          debugPrint('SupabaseService check error: $e');
          hasSession = false;
        }
      }

      if (!mounted || _hasNavigated) return;

      if (hasSession) {
        await _checkMotorAndNavigate(safeNavigate);
      } else {
        safeNavigate(const LoginPage());
      }
    } catch (e, stackTrace) {
      debugPrint('Splash initialization error: $e');
      debugPrint('Stack trace: $stackTrace');

      if (!_hasNavigated && mounted) {
        safeNavigate(const LoginPage());
      }
    }
  }

  Future<bool> _initializeSupabase() async {
    try {
      try {
        Supabase.instance.client;
        debugPrint('Supabase already initialized');
        return true;
      } catch (_) {
        final supabaseUrl = dotenv.env['SUPABASE_URL'];
        final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];

        if (supabaseUrl != null &&
            supabaseUrl.isNotEmpty &&
            supabaseAnonKey != null &&
            supabaseAnonKey.isNotEmpty) {
          await Supabase.initialize(
            url: supabaseUrl,
            anonKey: supabaseAnonKey,
            debug: false,
          ).timeout(const Duration(seconds: 3));

          debugPrint('Supabase initialized successfully');
          return true;
        }

        debugPrint('Supabase credentials not found');
        return false;
      }
    } catch (e) {
      debugPrint('Supabase init error: $e - Continuing in local mode');
      return false;
    }
  }

  Future<void> _checkMotorAndNavigate(
    void Function(Widget) safeNavigate,
  ) async {
    List<Map<String, dynamic>> motors = [];

    try {
      final dbHelper = DatabaseHelper();
      motors = await dbHelper.getMotors().timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          debugPrint('Get motors timeout - returning empty list');
          return <Map<String, dynamic>>[];
        },
      );
    } catch (e) {
      debugPrint('Get motors error: $e - Continuing with empty list');
      motors = [];
    }

    if (!mounted || _hasNavigated) return;

    if (motors.isEmpty) {
      safeNavigate(const MotorSetupPage());
    } else {
      safeNavigate(const NavBar());
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kAccent,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/logo.png',
              width: 140,
              height: 140,
            ),
            const SizedBox(height: 24),
            const Text(
              'MOTOBOX',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
                color: kBg,
              ),
            ),
            const SizedBox(height: 40),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(kBg),
            ),
          ],
        ),
      ),
    );
  }
}


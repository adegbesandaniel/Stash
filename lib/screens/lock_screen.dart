import 'dart:async';

import 'package:flutter/material.dart';

import '../services/security_service.dart';
import '../theme/app_theme.dart';
import 'dashboard_screen.dart';
import 'widgets/pin_keypad.dart';

/// Full-screen unlock gate shown on launch when App Lock is enabled.
class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  static const int _maxAttempts = 5;
  static const int _cooldownSeconds = 30;

  final SecurityService _security = SecurityService();
  String _entry = '';
  String? _error;
  bool _checking = false;
  bool _bioAvailable = false;

  int _failed = 0;
  int _cooldownRemaining = 0;
  Timer? _cooldownTimer;

  bool get _cooling => _cooldownRemaining > 0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    bool available = false;
    try {
      available = await _security.isBiometricEnabled() &&
          await _security.canUseBiometrics();
    } catch (_) {
      available = false;
    }
    if (!mounted) return;
    setState(() => _bioAvailable = available);
    if (available) _maybeBiometric();
  }

  Future<void> _maybeBiometric() async {
    if (!_bioAvailable || _cooling) return;
    try {
      final ok = await _security.authenticateBiometric();
      if (ok && mounted) _unlock();
    } catch (_) {}
  }

  void _unlock() {
    _cooldownTimer?.cancel();
    SecurityService.unlockedThisSession = true;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const DashboardScreen()),
    );
  }

  void _startCooldown() {
    setState(() {
      _cooldownRemaining = _cooldownSeconds;
      _entry = '';
      _error = 'Too many attempts. Try again in ${_cooldownRemaining}s.';
    });
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _cooldownRemaining--;
        if (_cooldownRemaining > 0) {
          _error = 'Too many attempts. Try again in ${_cooldownRemaining}s.';
        } else {
          _error = null;
          _failed = 0;
          timer.cancel();
        }
      });
    });
  }

  Future<void> _onKey(String k) async {
    if (_entry.length >= 4 || _checking || _cooling) return;
    setState(() {
      _entry += k;
      _error = null;
    });
    if (_entry.length == 4) {
      setState(() => _checking = true);
      final ok = await _security.verifyPin(_entry);
      if (!mounted) return;
      if (ok) {
        _unlock();
      } else {
        _failed++;
        if (_failed >= _maxAttempts) {
          _checking = false;
          _startCooldown();
        } else {
          final left = _maxAttempts - _failed;
          setState(() {
            _error = 'Incorrect PIN. $left attempt${left == 1 ? '' : 's'} left.';
            _entry = '';
            _checking = false;
          });
        }
      }
    }
  }

  void _onBackspace() {
    if (_entry.isEmpty || _cooling) return;
    setState(() => _entry = _entry.substring(0, _entry.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const SizedBox(height: 28),
              Container(
                height: 72,
                width: 72,
                decoration: BoxDecoration(
                  gradient: AppColors.heroGradient,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: AppShadow.heroGlow,
                ),
                child: const Center(
                  child: Text('S',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 38,
                          fontWeight: FontWeight.w900)),
                ),
              ),
              const SizedBox(height: 22),
              Text('Enter your PIN',
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: AppColors.text)),
              const SizedBox(height: 8),
              Text('Unlock STASH to continue.',
                  style: TextStyle(color: AppColors.muted)),
              const SizedBox(height: 30),
              PinDots(filled: _entry.length),
              const SizedBox(height: 14),
              SizedBox(
                height: 20,
                child: _error != null
                    ? Text(_error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: AppColors.danger,
                            fontWeight: FontWeight.w700))
                    : const SizedBox(),
              ),
              const Spacer(),
              PinKeypad(
                onKey: _onKey,
                onBackspace: _onBackspace,
                leftAction: _bioAvailable
                    ? IconButton(
                        onPressed: _cooling ? null : _maybeBiometric,
                        icon: Icon(Icons.fingerprint_rounded,
                            color: _cooling
                                ? AppColors.muted
                                : AppColors.primary,
                            size: 30),
                      )
                    : null,
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

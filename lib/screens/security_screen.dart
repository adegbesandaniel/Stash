import 'package:flutter/material.dart';

import '../services/notification_service.dart';
import '../services/security_service.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';
import 'set_pin_screen.dart';

/// Security & smart-saving preferences: App Lock (PIN), biometric unlock,
/// change PIN, push notifications, and Auto-Save round-ups.
class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  final SecurityService _security = SecurityService();
  final SettingsService _settings = SettingsService();

  bool _loading = true;
  bool _appLock = false;
  bool _biometric = false;
  bool _roundUps = false;
  bool _notifications = true;
  bool _hasPin = false;
  bool _canBiometric = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final appLock = await _security.isAppLockEnabled();
    final hasPin = await _security.hasPin();
    final biometric = await _security.isBiometricEnabled();
    final canBio = await _security.canUseBiometrics();
    final roundUps = await _settings.loadRoundUps();
    final notifications = await _settings.loadNotifications();
    if (!mounted) return;
    setState(() {
      _appLock = appLock;
      _hasPin = hasPin;
      _biometric = biometric;
      _canBiometric = canBio;
      _roundUps = roundUps;
      _notifications = notifications;
      _loading = false;
    });
  }

  void _showSnack(String message, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: success ? AppColors.success : AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<void> _toggleAppLock(bool v) async {
    if (_busy) return;
    _busy = true;
    try {
      if (v) {
        if (!_hasPin) {
          final created = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const SetPinScreen()),
          );
          if (created != true) return;
          _hasPin = true;
        }
        await _security.setAppLockEnabled(true);
        if (mounted) setState(() => _appLock = true);
        _showSnack('App Lock turned on', success: true);
      } else {
        await _security.setAppLockEnabled(false);
        await _security.setBiometricEnabled(false);
        if (mounted) {
          setState(() {
            _appLock = false;
            _biometric = false;
          });
        }
        _showSnack('App Lock turned off', success: true);
      }
    } catch (_) {
      _showSnack('Could not update App Lock. Try again.');
    } finally {
      _busy = false;
    }
  }

  Future<void> _toggleBiometric(bool v) async {
    if (v && !_canBiometric) {
      _showSnack('Biometrics are not set up on this device.');
      return;
    }
    try {
      await _security.setBiometricEnabled(v);
      if (mounted) setState(() => _biometric = v);
      _showSnack(v ? 'Biometric unlock on' : 'Biometric unlock off',
          success: true);
    } catch (_) {
      _showSnack('Could not update biometric unlock. Try again.');
    }
  }

  Future<void> _toggleNotifications(bool v) async {
    // Optimistically reflect the change, then persist the preference and
    // register/remove the device token accordingly.
    if (mounted) setState(() => _notifications = v);
    try {
      await _settings.saveNotifications(v);
      await NotificationService.instance.setEnabled(v);
      _showSnack(
          v ? 'Notifications turned on' : 'Notifications turned off',
          success: true);
    } catch (_) {
      if (mounted) setState(() => _notifications = !v);
      _showSnack('Could not update notifications. Try again.');
    }
  }

  Future<void> _toggleRoundUps(bool v) async {
    try {
      await _settings.saveRoundUps(v);
      if (mounted) setState(() => _roundUps = v);
    } catch (_) {
      _showSnack('Could not update Auto-Save. Try again.');
    }
  }

  Future<void> _changePin() async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const SetPinScreen()),
    );
    if (ok == true && mounted) {
      setState(() {
        _hasPin = true;
        _appLock = true;
      });
      _showSnack('PIN updated', success: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.text,
        elevation: 0,
        centerTitle: true,
        title: const Text('Security',
            style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _hero(),
                  const SizedBox(height: 22),
                  _switchTile(
                    Icons.lock_outline_rounded,
                    'App Lock',
                    'Require your PIN to open STASH',
                    _appLock,
                    _toggleAppLock,
                  ),
                  _switchTile(
                    Icons.fingerprint_rounded,
                    'Biometric Unlock',
                    _canBiometric
                        ? 'Use fingerprint or Face ID'
                        : 'Not available on this device',
                    _biometric,
                    (_appLock && _canBiometric) ? _toggleBiometric : null,
                  ),
                  if (_hasPin)
                    _actionTile(
                        Icons.password_rounded, 'Change PIN', _changePin),
                  const SizedBox(height: 18),
                  Text('Notifications',
                      style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: AppColors.text,
                          fontSize: 15)),
                  const SizedBox(height: 12),
                  _switchTile(
                    Icons.notifications_active_rounded,
                    'Push Notifications',
                    'Transaction alerts and daily budget reminders',
                    _notifications,
                    _toggleNotifications,
                  ),
                  const SizedBox(height: 18),
                  Text('Smart Saving',
                      style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: AppColors.text,
                          fontSize: 15)),
                  const SizedBox(height: 12),
                  _switchTile(
                    Icons.savings_rounded,
                    'Auto-Save Round-ups',
                    'Round spending up to \u20a6100 and stash the change',
                    _roundUps,
                    _toggleRoundUps,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _hero() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadow.heroGlow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Icon(Icons.shield_rounded, color: Colors.white, size: 38),
          SizedBox(height: 16),
          Text('Protect your money',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5)),
          SizedBox(height: 8),
          Text(
              'Lock STASH with a PIN or biometrics so only you can access your account.',
              style: TextStyle(color: Colors.white70, height: 1.5)),
        ],
      ),
    );
  }

  Widget _switchTile(IconData icon, String title, String subtitle, bool value,
      ValueChanged<bool>? onChanged) {
    final disabled = onChanged == null;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadow.soft,
      ),
      child: Row(
        children: [
          Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: disabled ? AppColors.muted : AppColors.text)),
                const SizedBox(height: 3),
                Text(subtitle,
                    style: TextStyle(color: AppColors.muted, fontSize: 12)),
              ],
            ),
          ),
          Switch(
            value: value,
            activeColor: AppColors.primary,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _actionTile(IconData icon, String title, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: AppShadow.soft,
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.text),
            const SizedBox(width: 14),
            Expanded(
              child: Text(title,
                  style: TextStyle(
                      fontWeight: FontWeight.w800, color: AppColors.text)),
            ),
            Icon(Icons.chevron_right_rounded, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}

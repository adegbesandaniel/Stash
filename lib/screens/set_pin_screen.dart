import 'package:flutter/material.dart';

import '../services/security_service.dart';
import '../theme/app_theme.dart';
import 'widgets/pin_keypad.dart';

/// Create + confirm a 4-digit PIN. Pops `true` when a PIN is saved.
class SetPinScreen extends StatefulWidget {
  const SetPinScreen({super.key});

  @override
  State<SetPinScreen> createState() => _SetPinScreenState();
}

class _SetPinScreenState extends State<SetPinScreen> {
  String _first = '';
  String _entry = '';
  bool _confirming = false;
  bool _saving = false;
  String? _error;

  void _onKey(String k) {
    if (_entry.length >= 4 || _saving) return;
    setState(() {
      _entry += k;
      _error = null;
    });
    if (_entry.length == 4) _handleComplete();
  }

  void _onBackspace() {
    if (_entry.isEmpty || _saving) return;
    setState(() => _entry = _entry.substring(0, _entry.length - 1));
  }

  Future<void> _handleComplete() async {
    if (!_confirming) {
      // Reject trivially guessable PINs before asking to confirm.
      if (SecurityService.isWeakPin(_entry)) {
        setState(() {
          _error = 'Choose a less predictable PIN.';
          _entry = '';
        });
        return;
      }
      setState(() {
        _first = _entry;
        _entry = '';
        _confirming = true;
      });
      return;
    }
    if (_entry != _first) {
      setState(() {
        _error = 'PINs do not match. Try again.';
        _entry = '';
        _first = '';
        _confirming = false;
      });
      return;
    }
    setState(() => _saving = true);
    final err = await SecurityService().setPin(_entry);
    if (!mounted) return;
    if (err != null) {
      // Reset fully so the keypad is usable again after a failure.
      setState(() {
        _saving = false;
        _error = err;
        _entry = '';
        _first = '';
        _confirming = false;
      });
      return;
    }
    setState(() => _saving = false);
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final title = _confirming ? 'Confirm your PIN' : 'Create a PIN';
    final subtitle = _confirming
        ? 'Re-enter your 4-digit PIN to confirm.'
        : 'Set a 4-digit PIN to secure your STASH app.';
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.text,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const SizedBox(height: 6),
              Container(
                height: 64,
                width: 64,
                decoration: BoxDecoration(
                  gradient: AppColors.heroGradient,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: AppShadow.heroGlow,
                ),
                child: const Icon(Icons.lock_rounded,
                    color: Colors.white, size: 30),
              ),
              const SizedBox(height: 22),
              Text(title,
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: AppColors.text)),
              const SizedBox(height: 8),
              Text(subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted, height: 1.4)),
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
              if (_saving)
                const Padding(
                  padding: EdgeInsets.only(bottom: 40),
                  child: CircularProgressIndicator(),
                )
              else
                PinKeypad(onKey: _onKey, onBackspace: _onBackspace),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Row of dots showing how many PIN digits have been entered.
class PinDots extends StatelessWidget {
  final int length;
  final int filled;
  const PinDots({super.key, this.length = 4, required this.filled});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(length, (i) {
        final active = i < filled;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          margin: const EdgeInsets.symmetric(horizontal: 10),
          height: 18,
          width: 18,
          decoration: BoxDecoration(
            color: active ? AppColors.primary : Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(
                color: active ? AppColors.primary : AppColors.border,
                width: 2),
          ),
        );
      }),
    );
  }
}

/// 3x4 numeric keypad used by the PIN setup and lock screens.
class PinKeypad extends StatelessWidget {
  final ValueChanged<String> onKey;
  final VoidCallback onBackspace;
  final Widget? leftAction;
  const PinKeypad({
    super.key,
    required this.onKey,
    required this.onBackspace,
    this.leftAction,
  });

  @override
  Widget build(BuildContext context) {
    const keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9'];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int r = 0; r < 3; r++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [for (int c = 0; c < 3; c++) _key(keys[r * 3 + c])],
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              SizedBox(
                width: 72,
                height: 72,
                child: Center(child: leftAction ?? const SizedBox()),
              ),
              _key('0'),
              SizedBox(
                width: 72,
                height: 72,
                child: IconButton(
                  onPressed: onBackspace,
                  icon: Icon(Icons.backspace_outlined, color: AppColors.text),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _key(String k) => _PinKeyButton(label: k, onTap: () => onKey(k));
}

class _PinKeyButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _PinKeyButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(40),
      child: Container(
        height: 72,
        width: 72,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.card,
          shape: BoxShape.circle,
          boxShadow: AppShadow.soft,
        ),
        child: Text(
          label,
          style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppColors.text),
        ),
      ),
    );
  }
}

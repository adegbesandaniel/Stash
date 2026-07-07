import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/security_service.dart';
import '../theme/app_theme.dart';
import 'signup_screen.dart';
import 'dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final passwordFocus = FocusNode();

  bool isLoading = false;
  bool hidePassword = true;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    passwordFocus.dispose();
    super.dispose();
  }

  String? _emailValidator(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return 'Email is required';
    final regex = RegExp(r'^[\w.\-+]+@([\w\-]+\.)+[\w\-]{2,}$');
    if (!regex.hasMatch(value)) return 'Enter a valid email address';
    return null;
  }

  String? _passwordValidator(String? v) {
    final value = v ?? '';
    if (value.isEmpty) return 'Password is required';
    if (value.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
      ));
  }

  void _social(String provider) {
    _showSnack('$provider sign-in is coming soon.');
  }

  Future<void> loginUser() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    final error = await AuthService().login(
      email: emailController.text,
      password: passwordController.text,
    );

    if (!mounted) return;
    setState(() => isLoading = false);

    if (error != null) {
      _showSnack(error);
      return;
    }

    // A fresh manual login counts as an unlock for this session.
    SecurityService.unlockedThisSession = true;

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const DashboardScreen()),
    );
  }

  Future<void> forgotPassword() async {
    final resetController =
        TextEditingController(text: emailController.text.trim());
    final dialogKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (ctx) {
        bool sending = false;
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              backgroundColor: AppColors.card,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md)),
              title: Text('Reset Password',
                  style: TextStyle(
                      fontWeight: FontWeight.w900, color: AppColors.text)),
              content: Form(
                key: dialogKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        'Enter your email and we will send you a reset link.',
                        style:
                            TextStyle(color: AppColors.muted, height: 1.4)),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: resetController,
                      keyboardType: TextInputType.emailAddress,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      validator: _emailValidator,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.text),
                      decoration: InputDecoration(
                        labelText: 'Email Address',
                        labelStyle: TextStyle(color: AppColors.muted),
                        prefixIcon: Icon(Icons.email_outlined,
                            color: AppColors.primary),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: sending ? null : () => Navigator.pop(ctx),
                  child: Text('Cancel',
                      style: TextStyle(color: AppColors.muted)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.hero,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.sm)),
                  ),
                  onPressed: sending
                      ? null
                      : () async {
                          if (!dialogKey.currentState!.validate()) return;
                          setLocal(() => sending = true);
                          final err = await AuthService()
                              .resetPassword(resetController.text);
                          setLocal(() => sending = false);
                          if (!ctx.mounted) return;
                          Navigator.pop(ctx);
                          _showSnack(
                              err ?? 'Reset link sent. Check your email.');
                        },
                  child: sending
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.2, color: Color(0xFF0A0A0C)))
                      : const Text('Send',
                          style: TextStyle(
                              color: Color(0xFF0A0A0C),
                              fontWeight: FontWeight.w800)),
                ),
              ],
            );
          },
        );
      },
    );
    resetController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 44, 24, 30),
          child: Form(
            key: _formKey,
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Welcome back',
                      style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          color: AppColors.text,
                          letterSpacing: -1)),
                  const SizedBox(height: 8),
                  Text('Log in to continue managing your money.',
                      style: TextStyle(
                          color: AppColors.muted, fontSize: 15, height: 1.5)),
                  const SizedBox(height: 36),
                  _field(
                    controller: emailController,
                    label: 'Email address',
                    hint: 'name@email.com',
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    validator: _emailValidator,
                    autofillHints: const [AutofillHints.email],
                    onSubmitted: (_) => passwordFocus.requestFocus(),
                  ),
                  const SizedBox(height: 16),
                  _field(
                    controller: passwordController,
                    focusNode: passwordFocus,
                    label: 'Password',
                    hint: '\u2022\u2022\u2022\u2022\u2022\u2022\u2022\u2022',
                    obscureText: hidePassword,
                    textInputAction: TextInputAction.done,
                    validator: _passwordValidator,
                    autofillHints: const [AutofillHints.password],
                    onSubmitted: (_) => loginUser(),
                    suffixIcon: IconButton(
                      icon: Icon(
                          hidePassword
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          color: AppColors.muted),
                      onPressed: () =>
                          setState(() => hidePassword = !hidePassword),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      onTap: isLoading ? null : forgotPassword,
                      child: Text('Forgot password?',
                          style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w800)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _primaryButton(
                      text: 'Log in',
                      loading: isLoading,
                      onPressed: isLoading ? null : loginUser),
                  const SizedBox(height: 28),
                  _orDivider(),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: _socialButton(
                          label: 'Apple',
                          leading: const Text('\u{1F34E}',
                              style: TextStyle(fontSize: 18)),
                          onTap: () => _social('Apple'),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _socialButton(
                          label: 'Google',
                          leading: Text('G',
                              style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.text)),
                          onTap: () => _social('Google'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("Don't have an account? ",
                            style: TextStyle(color: AppColors.muted)),
                        GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const SignupScreen()),
                          ),
                          child: const Text('Sign up',
                              style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w900)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    FocusNode? focusNode,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputAction? textInputAction,
    String? Function(String?)? validator,
    Iterable<String>? autofillHints,
    ValueChanged<String>? onSubmitted,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.fromLTRB(18, 12, 10, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        color: AppColors.muted,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700)),
                TextFormField(
                  controller: controller,
                  focusNode: focusNode,
                  keyboardType: keyboardType,
                  obscureText: obscureText,
                  textInputAction: textInputAction,
                  autofillHints: autofillHints,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: validator,
                  onFieldSubmitted: onSubmitted,
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                      fontSize: 16),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: TextStyle(
                        color: AppColors.muted, fontWeight: FontWeight.w600),
                    isDense: true,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 4),
                    errorStyle: const TextStyle(
                        color: AppColors.danger, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          if (suffixIcon != null) suffixIcon,
        ],
      ),
    );
  }

  Widget _orDivider() {
    return Row(
      children: [
        Expanded(child: Divider(color: AppColors.border, thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('or continue with',
              style: TextStyle(color: AppColors.muted, fontSize: 13)),
        ),
        Expanded(child: Divider(color: AppColors.border, thickness: 1)),
      ],
    );
  }

  Widget _socialButton({
    required String label,
    required Widget leading,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.card,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              side: BorderSide(color: AppColors.border)),
        ),
        onPressed: onTap,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            leading,
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.w800,
                    fontSize: 15)),
          ],
        ),
      ),
    );
  }

  Widget _primaryButton({
    required String text,
    required bool loading,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.hero,
          disabledBackgroundColor: AppColors.hero.withOpacity(0.7),
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md)),
        ),
        onPressed: onPressed,
        child: loading
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.4, color: Color(0xFF0A0A0C)))
            : Text(text,
                style: const TextStyle(
                    color: Color(0xFF0A0A0C),
                    fontSize: 17,
                    fontWeight: FontWeight.w900)),
      ),
    );
  }
}

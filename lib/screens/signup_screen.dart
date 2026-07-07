import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/auth_service.dart';
import '../services/security_service.dart';
import '../theme/app_theme.dart';
import 'dashboard_screen.dart';

class _Country {
  final String name;
  final String dialCode;
  final String flag;
  const _Country(this.name, this.dialCode, this.flag);
}

const List<_Country> _countries = [
  _Country('Nigeria', '+234', '\u{1F1F3}\u{1F1EC}'),
  _Country('Ghana', '+233', '\u{1F1EC}\u{1F1ED}'),
  _Country('Kenya', '+254', '\u{1F1F0}\u{1F1EA}'),
  _Country('South Africa', '+27', '\u{1F1FF}\u{1F1E6}'),
  _Country('Egypt', '+20', '\u{1F1EA}\u{1F1EC}'),
  _Country('Cameroon', '+237', '\u{1F1E8}\u{1F1F2}'),
  _Country('Ivory Coast', '+225', '\u{1F1E8}\u{1F1EE}'),
  _Country('Senegal', '+221', '\u{1F1F8}\u{1F1F3}'),
  _Country('Uganda', '+256', '\u{1F1FA}\u{1F1EC}'),
  _Country('Tanzania', '+255', '\u{1F1F9}\u{1F1FF}'),
  _Country('Rwanda', '+250', '\u{1F1F7}\u{1F1FC}'),
  _Country('United States', '+1', '\u{1F1FA}\u{1F1F8}'),
  _Country('United Kingdom', '+44', '\u{1F1EC}\u{1F1E7}'),
  _Country('Canada', '+1', '\u{1F1E8}\u{1F1E6}'),
  _Country('India', '+91', '\u{1F1EE}\u{1F1F3}'),
  _Country('United Arab Emirates', '+971', '\u{1F1E6}\u{1F1EA}'),
];

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();

  final emailFocus = FocusNode();
  final phoneFocus = FocusNode();
  final passwordFocus = FocusNode();

  _Country selectedCountry = _countries.first;
  bool isLoading = false;
  bool hidePassword = true;
  bool agreedToTerms = false;

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    emailFocus.dispose();
    phoneFocus.dispose();
    passwordFocus.dispose();
    super.dispose();
  }

  String? _nameValidator(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return 'Full name is required';
    if (value.length < 2) return 'Enter your full name';
    return null;
  }

  String? _emailValidator(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return 'Email is required';
    final regex = RegExp(r'^[\w.\-+]+@([\w\-]+\.)+[\w\-]{2,}$');
    if (!regex.hasMatch(value)) return 'Enter a valid email address';
    return null;
  }

  String? _phoneValidator(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return 'Phone number is required';
    if (value.length < 7) return 'Enter a valid phone number';
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

  String get _fullPhone {
    final raw = phoneController.text.trim();
    final local = raw.startsWith('0') ? raw.substring(1) : raw;
    return '${selectedCountry.dialCode}$local';
  }

  Future<void> _pickCountry() async {
    FocusScope.of(context).unfocus();
    final picked = await showModalBottomSheet<_Country>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CountryPickerSheet(selected: selectedCountry),
    );
    if (picked != null && mounted) {
      setState(() => selectedCountry = picked);
    }
  }

  Future<void> createAccount() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    if (!agreedToTerms) {
      _showSnack('Please agree to the Terms of service and privacy policy.');
      return;
    }

    setState(() => isLoading = true);

    final error = await AuthService().signUp(
      name: nameController.text,
      email: emailController.text,
      phone: _fullPhone,
      password: passwordController.text,
    );

    if (!mounted) return;
    setState(() => isLoading = false);

    if (error != null) {
      _showSnack(error);
      return;
    }

    SecurityService.unlockedThisSession = true;

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const DashboardScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 30),
          child: Form(
            key: _formKey,
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.maybePop(context),
                    child: Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Icon(Icons.arrow_back_rounded,
                          size: 20, color: AppColors.text),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text('Create your account',
                      style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: AppColors.text,
                          letterSpacing: -1)),
                  const SizedBox(height: 8),
                  Text('It takes less than two minutes.',
                      style: TextStyle(
                          color: AppColors.muted, fontSize: 15, height: 1.5)),
                  const SizedBox(height: 28),
                  _field(
                    controller: nameController,
                    label: 'Full name',
                    hint: 'Daniel Adebayo',
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    validator: _nameValidator,
                    autofillHints: const [AutofillHints.name],
                    onSubmitted: (_) => emailFocus.requestFocus(),
                  ),
                  const SizedBox(height: 16),
                  _field(
                    controller: emailController,
                    focusNode: emailFocus,
                    label: 'Email address',
                    hint: 'name@email.com',
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    validator: _emailValidator,
                    autofillHints: const [AutofillHints.email],
                    onSubmitted: (_) => phoneFocus.requestFocus(),
                  ),
                  const SizedBox(height: 16),
                  _phoneField(),
                  const SizedBox(height: 16),
                  _field(
                    controller: passwordController,
                    focusNode: passwordFocus,
                    label: 'Password',
                    hint: '\u2022\u2022\u2022\u2022\u2022\u2022\u2022\u2022',
                    obscureText: hidePassword,
                    textInputAction: TextInputAction.done,
                    validator: _passwordValidator,
                    autofillHints: const [AutofillHints.newPassword],
                    onSubmitted: (_) => createAccount(),
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
                  const SizedBox(height: 20),
                  _termsRow(),
                  const SizedBox(height: 24),
                  _primaryButton(
                      text: 'Create account',
                      loading: isLoading,
                      onPressed: isLoading ? null : createAccount),
                  const SizedBox(height: 24),
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Already have an account? ',
                            style: TextStyle(color: AppColors.muted)),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Text('Log in',
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

  Widget _termsRow() {
    return GestureDetector(
      onTap: () => setState(() => agreedToTerms = !agreedToTerms),
      behavior: HitTestBehavior.opaque,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: agreedToTerms ? AppColors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: agreedToTerms ? AppColors.primary : AppColors.border,
                  width: 1.6),
            ),
            child: agreedToTerms
                ? const Icon(Icons.check_rounded,
                    size: 17, color: AppColors.onAccent)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Text.rich(
                TextSpan(
                  style: TextStyle(
                      color: AppColors.muted, fontSize: 13.5, height: 1.45),
                  children: [
                    const TextSpan(text: "I agree to Stash's "),
                    TextSpan(
                        text: 'Terms of service',
                        style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w800)),
                    const TextSpan(text: ' and '),
                    TextSpan(
                        text: 'privacy policy',
                        style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w800)),
                    const TextSpan(text: '.'),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _phoneField() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.fromLTRB(18, 12, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Phone number',
              style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700)),
          Row(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: _pickCountry,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(selectedCountry.flag,
                          style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 6),
                      Text(selectedCountry.dialCode,
                          style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: AppColors.text,
                              fontSize: 16)),
                      Icon(Icons.arrow_drop_down_rounded,
                          color: AppColors.muted),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(height: 24, width: 1, color: AppColors.border),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: phoneController,
                  focusNode: phoneFocus,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.telephoneNumber],
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: _phoneValidator,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
                    LengthLimitingTextInputFormatter(13),
                  ],
                  onFieldSubmitted: (_) => passwordFocus.requestFocus(),
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                      fontSize: 16),
                  decoration: InputDecoration(
                    hintText: '080 1234 5678',
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
              ),
            ],
          ),
        ],
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
    TextCapitalization textCapitalization = TextCapitalization.none,
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
                  textCapitalization: textCapitalization,
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

class _CountryPickerSheet extends StatefulWidget {
  final _Country selected;
  const _CountryPickerSheet({required this.selected});

  @override
  State<_CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<_CountryPickerSheet> {
  final searchController = TextEditingController();
  late List<_Country> filtered = _countries;

  void _filter(String q) {
    final query = q.trim().toLowerCase();
    setState(() {
      filtered = query.isEmpty
          ? _countries
          : _countries
              .where((c) =>
                  c.name.toLowerCase().contains(query) ||
                  c.dialCode.contains(query))
              .toList();
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            Container(
              height: 5,
              width: 46,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Select Country',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppColors.text)),
            ),
            const SizedBox(height: 14),
            Container(
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(AppRadius.md),
                boxShadow: AppShadow.soft,
              ),
              child: TextField(
                controller: searchController,
                onChanged: _filter,
                style: TextStyle(
                    fontWeight: FontWeight.w700, color: AppColors.text),
                decoration: InputDecoration(
                  hintText: 'Search country or code',
                  hintStyle: TextStyle(color: AppColors.muted),
                  prefixIcon:
                      Icon(Icons.search_rounded, color: AppColors.muted),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text('No countries found',
                          style: TextStyle(color: AppColors.muted)))
                  : ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) =>
                          Divider(height: 1, color: AppColors.border),
                      itemBuilder: (context, i) {
                        final c = filtered[i];
                        final isSel = c.name == widget.selected.name &&
                            c.dialCode == widget.selected.dialCode;
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          onTap: () => Navigator.pop(context, c),
                          leading: Text(c.flag,
                              style: const TextStyle(fontSize: 26)),
                          title: Text(c.name,
                              style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.text)),
                          trailing: Text(c.dialCode,
                              style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: isSel
                                      ? AppColors.primary
                                      : AppColors.muted)),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

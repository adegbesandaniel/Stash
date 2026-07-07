import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/transaction_model.dart';
import '../services/balance_service.dart';
import '../services/firestore_service.dart';
import '../services/payment_service.dart';
import '../theme/app_theme.dart';
import '../utils/money.dart';
import 'widgets/success_dialog.dart';

/// STASH — Send Money (black liquid UI).
///
/// Records an `expense` transaction (category 'Transfer') via
/// FirestoreService().addTransaction(). Resolves the recipient's REAL account
/// name via Paystack's account-resolution API for new recipients, and keeps a
/// list of REAL Nigerian banks with their Paystack bank codes.
///
/// Note: the actual debit/payout is still recorded locally as an expense —
/// moving real money requires the Paystack Transfers (payout) API + a funded
/// balance + a backend, which is a separate, larger feature.
class TransferScreen extends StatefulWidget {
  const TransferScreen({super.key});

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

/// A Nigerian bank and its Paystack bank code.
class _Bank {
  final String name;
  final String code;
  const _Bank(this.name, this.code);
}

/// A saved/recent recipient shortcut.
class _Recipient {
  final String fullName;
  final String shortName;
  final String initials;
  final String bankCode;
  final String account;
  const _Recipient(
      this.fullName, this.shortName, this.initials, this.bankCode, this.account);
}

class _TransferScreenState extends State<TransferScreen> {
  final accountController = TextEditingController();
  final amountController = TextEditingController(text: '25000');
  final noteController = TextEditingController(text: 'Rent contribution');

  _Bank? selectedBank;
  String? resolvedName;
  String? resolveError;
  bool isResolving = false;
  bool isLoading = false;
  int _resolveToken = 0;
  int selectedRecipient = 0; // -1 = New
  double? _available;

  static const double _minAmount = 50;
  static const double _maxAmount = 10000000;

  /// Real Nigerian banks with their Paystack bank codes.
  static const List<_Bank> _banks = [
    _Bank('Access Bank', '044'),
    _Bank('Citibank Nigeria', '023'),
    _Bank('Ecobank Nigeria', '050'),
    _Bank('Fidelity Bank', '070'),
    _Bank('First Bank of Nigeria', '011'),
    _Bank('First City Monument Bank (FCMB)', '214'),
    _Bank('Globus Bank', '00103'),
    _Bank('Guaranty Trust Bank (GTBank)', '058'),
    _Bank('Heritage Bank', '030'),
    _Bank('Jaiz Bank', '301'),
    _Bank('Keystone Bank', '082'),
    _Bank('Kuda Microfinance Bank', '50211'),
    _Bank('Moniepoint MFB', '50515'),
    _Bank('Opay Digital Services', '999992'),
    _Bank('PalmPay', '999991'),
    _Bank('Polaris Bank', '076'),
    _Bank('Providus Bank', '101'),
    _Bank('Stanbic IBTC Bank', '221'),
    _Bank('Standard Chartered Bank', '068'),
    _Bank('Sterling Bank', '232'),
    _Bank('SunTrust Bank', '100'),
    _Bank('TAJBank', '302'),
    _Bank('Titan Trust Bank', '102'),
    _Bank('Union Bank of Nigeria', '032'),
    _Bank('United Bank for Africa (UBA)', '033'),
    _Bank('Unity Bank', '215'),
    _Bank('Wema Bank (ALAT)', '035'),
    _Bank('Zenith Bank', '057'),
  ];

  static const List<_Recipient> _recipients = [
    _Recipient('Jide Kalu', 'Jide K.', 'JK', '058', '0123456789'),
    _Recipient('Amara Musa', 'Amara', 'AM', '033', '2234567890'),
    _Recipient('Tunde Folake', 'Tunde', 'TF', '044', '3344556677'),
  ];

  @override
  void initState() {
    super.initState();
    // Open pre-filled with the first recent recipient to mirror the design.
    _applyRecipient(0);
    _loadBalance();
    amountController.addListener(_onAmountChanged);
  }

  void _onAmountChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadBalance() async {
    final snap = await BalanceService().snapshot();
    if (!mounted) return;
    setState(() => _available = snap.available);
  }

  @override
  void dispose() {
    amountController.removeListener(_onAmountChanged);
    accountController.dispose();
    amountController.dispose();
    noteController.dispose();
    super.dispose();
  }

  _Bank _bankByCode(String code) =>
      _banks.firstWhere((b) => b.code == code, orElse: () => _banks.first);

  void _applyRecipient(int index) {
    final r = _recipients[index];
    setState(() {
      selectedRecipient = index;
      selectedBank = _bankByCode(r.bankCode);
      accountController.text = r.account;
      resolvedName = r.fullName;
      resolveError = null;
      isResolving = false;
    });
  }

  void _newRecipient() {
    setState(() {
      selectedRecipient = -1;
      selectedBank = null;
      accountController.clear();
      resolvedName = null;
      resolveError = null;
    });
    _selectBank();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  // ---- Bank selection ----
  Future<void> _selectBank() async {
    FocusScope.of(context).unfocus();
    final selected = await showModalBottomSheet<_Bank>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BankPickerSheet(banks: _banks, selected: selectedBank),
    );
    if (selected != null && mounted) {
      setState(() {
        selectedBank = selected;
        selectedRecipient = -1;
      });
      _maybeResolveName();
    }
  }

  // ---- Account number entry ----
  Future<void> _editAccount() async {
    final controller = TextEditingController(text: accountController.text);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _InputSheet(
        title: 'Account number',
        hint: '10-digit account number',
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(10),
        ],
        onDone: (v) {
          setState(() {
            accountController.text = v;
            selectedRecipient = -1;
            resolvedName = null;
          });
          _maybeResolveName();
        },
      ),
    );
  }

  // ---- Narration entry ----
  Future<void> _editNote() async {
    final controller = TextEditingController(text: noteController.text);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _InputSheet(
        title: 'Narration',
        hint: 'What is this for?',
        controller: controller,
        textCapitalization: TextCapitalization.sentences,
        onDone: (v) => setState(() => noteController.text = v),
      ),
    );
  }

  // ---- Account name resolution (real Paystack lookup) ----
  void _maybeResolveName() {
    final account = accountController.text.trim();
    if (account.length == 10 && selectedBank != null) {
      _resolveName(account, selectedBank!);
    } else {
      setState(() {
        resolvedName = null;
        resolveError = null;
        isResolving = false;
      });
    }
  }

  Future<void> _resolveName(String account, _Bank bank) async {
    final token = ++_resolveToken;
    setState(() {
      isResolving = true;
      resolvedName = null;
      resolveError = null;
    });

    try {
      final result = await PaymentService().resolveAccount(
        accountNumber: account,
        bankCode: bank.code,
      );
      if (!mounted || token != _resolveToken) return;
      setState(() {
        resolvedName = result.name;
        resolveError = result.name == null
            ? 'We couldn\u2019t auto-verify this account name. You can still continue \u2014 just double-check the number before sending.'
            : null;
        isResolving = false;
      });
    } catch (e) {
      if (!mounted || token != _resolveToken) return;
      setState(() {
        resolvedName = null;
        resolveError =
            'We couldn\u2019t auto-verify this account name. You can still continue \u2014 just double-check the number before sending.';
        isResolving = false;
      });
    }
  }

  Future<void> simulateTransfer() async {
    FocusScope.of(context).unfocus();

    final account = accountController.text.trim();
    final bank = selectedBank;
    final rawAmount = amountController.text.trim();
    final amount = double.tryParse(rawAmount);

    if (bank == null) {
      _showError('Please select the recipient\'s bank.');
      return;
    }
    if (account.length < 10 || !RegExp(r'^\d+$').hasMatch(account)) {
      _showError('Enter a valid 10-digit account number.');
      return;
    }
    if (isResolving) {
      _showError('Please wait while we confirm the recipient name.');
      return;
    }
    if (rawAmount.isEmpty || amount == null || amount <= 0) {
      _showError('Enter a valid amount greater than zero.');
      return;
    }
    if (amount < _minAmount) {
      _showError('Minimum transfer amount is ${Money.naira(_minAmount)}.');
      return;
    }
    if (amount > _maxAmount) {
      _showError('Amount is too large. Maximum is ${Money.naira(_maxAmount)}.');
      return;
    }

    final receiver = resolvedName ?? 'Account $account';

    setState(() => isLoading = true);

    final guard = await BalanceService().guardSpend(amount);
    if (!mounted) return;
    if (guard != null) {
      setState(() => isLoading = false);
      _showError(guard);
      return;
    }

    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final note = noteController.text.trim();
    final transaction = TransactionModel(
      type: 'expense',
      category: 'Transfer',
      amount: amount,
      note: note.isEmpty
          ? 'Transfer to $receiver \u2022 ${bank.name} ($account)'
          : '$note (Transfer to $receiver \u2022 ${bank.name} $account)',
      date: DateTime.now(),
    );

    final error = await FirestoreService().addTransaction(transaction);
    if (!mounted) return;
    setState(() => isLoading = false);

    if (error != null) {
      _showError(error);
      return;
    }

    amountController.clear();
    noteController.clear();
    setState(() {
      selectedRecipient = -1;
      selectedBank = null;
      resolvedName = null;
      resolveError = null;
    });
    accountController.clear();
    _loadBalance();

    await completeTransaction(
      context,
      title: 'Transfer Successful',
      message: 'You sent ${Money.naira(amount)} to $receiver (${bank.name}).',
      amount: amount,
      type: 'expense',
      category: 'Transfer',
      note: transaction.note,
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: AppColors.text),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Send money',
            style: TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.w800,
                fontSize: 20)),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Recent recipients',
                  style: TextStyle(
                      color: AppColors.text,
                      fontWeight: FontWeight.w800,
                      fontSize: 15)),
              const SizedBox(height: 16),
              _recipientsRow(),
              const SizedBox(height: 24),
              _amountCard(),
              const SizedBox(height: 18),
              _detailRow(
                label: 'Recipient',
                value: resolvedName != null
                    ? '$resolvedName \u00b7 ${_shortBank(selectedBank?.name ?? '')}'
                    : 'Select recipient',
                strong: resolvedName != null,
                trailing: isResolving ? _miniLoader() : null,
                onTap: _selectBank,
              ),
              const SizedBox(height: 12),
              _detailRow(
                label: 'Account number',
                value: accountController.text.isEmpty
                    ? 'Tap to enter'
                    : _formatAccount(accountController.text),
                strong: accountController.text.isNotEmpty,
                onTap: _editAccount,
              ),
              const SizedBox(height: 12),
              _detailRow(
                label: 'Narration',
                value: noteController.text.isEmpty
                    ? 'Add a note'
                    : noteController.text,
                strong: noteController.text.isNotEmpty,
                onTap: _editNote,
              ),
              const SizedBox(height: 12),
              _detailRow(
                label: 'Transfer fee',
                value: '\u20A60 \u00b7 Stash covers it',
                strong: true,
              ),
              const SizedBox(height: 28),
              _confirmButton(),
              const SizedBox(height: 14),
              Center(
                child: Text(
                  'Recipient name auto-verified when available \u00b7 recorded as an expense',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted, fontSize: 11.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---- Recent recipients ----
  Widget _recipientsRow() {
    return SizedBox(
      height: 92,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        children: [
          _recipientAvatar(
            label: 'New',
            isNew: true,
            selected: selectedRecipient == -1,
            onTap: _newRecipient,
          ),
          for (int i = 0; i < _recipients.length; i++)
            _recipientAvatar(
              label: _recipients[i].shortName,
              initials: _recipients[i].initials,
              selected: selectedRecipient == i,
              onTap: () => _applyRecipient(i),
            ),
        ],
      ),
    );
  }

  Widget _recipientAvatar({
    String? initials,
    required String label,
    bool isNew = false,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 18),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          children: [
            Container(
              height: 58,
              width: 58,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.card,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? AppColors.primary : AppColors.border,
                  width: selected ? 2 : 1,
                ),
              ),
              child: isNew
                  ? Icon(Icons.add_rounded, color: AppColors.primary, size: 26)
                  : Text(initials ?? '',
                      style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w900,
                          fontSize: 16)),
            ),
            const SizedBox(height: 8),
            Text(label,
                style: TextStyle(
                    color: selected ? AppColors.text : AppColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  // ---- Amount card ----
  Widget _amountCard() {
    final amount = double.tryParse(amountController.text.trim()) ?? 0;
    final after = (_available ?? 0) - amount;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadow.heroGlow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: Container(
          decoration: BoxDecoration(
            gradient: AppColors.heroGradient,
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -30,
                top: -30,
                child: Container(
                  height: 130,
                  width: 130,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      AppColors.primary.withOpacity(0.26),
                      AppColors.primary.withOpacity(0.0),
                    ]),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Amount to send',
                        style:
                            TextStyle(color: Colors.white70, fontSize: 13.5)),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Text('\u20A6',
                              style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900)),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: TextField(
                            controller: amountController,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9.]')),
                            ],
                            cursorColor: AppColors.primary,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 40,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1,
                            ),
                            decoration: const InputDecoration(
                              isDense: true,
                              border: InputBorder.none,
                              hintText: '0',
                              hintStyle: TextStyle(
                                  color: Colors.white24,
                                  fontSize: 40,
                                  fontWeight: FontWeight.w900),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _available == null
                          ? 'Balance after transfer: \u2014'
                          : 'Balance after transfer: ${Money.naira(after < 0 ? 0 : after)}',
                      style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---- Detail row ----
  Widget _detailRow({
    required String label,
    required String value,
    VoidCallback? onTap,
    bool strong = false,
    Widget? trailing,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: AppShadow.soft,
        ),
        child: Row(
          children: [
            Text(label,
                style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600)),
            const Spacer(),
            if (trailing != null) ...[trailing, const SizedBox(width: 10)],
            Flexible(
              child: Text(value,
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: strong ? AppColors.text : AppColors.muted,
                      fontWeight: FontWeight.w800,
                      fontSize: 14)),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 6),
              Icon(Icons.chevron_right_rounded,
                  color: AppColors.muted, size: 18),
            ],
          ],
        ),
      ),
    );
  }

  Widget _miniLoader() => const SizedBox(
        height: 16,
        width: 16,
        child: CircularProgressIndicator(
            strokeWidth: 2, color: AppColors.primary),
      );

  // ---- Confirm button ----
  Widget _confirmButton() {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.hero,
          disabledBackgroundColor: AppColors.hero.withOpacity(0.6),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
        ),
        onPressed: isLoading ? null : simulateTransfer,
        child: isLoading
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.4, color: Color(0xFF0A0A0C)),
              )
            : const Text('Confirm transfer',
                style: TextStyle(
                    color: Color(0xFF0A0A0C),
                    fontSize: 17,
                    fontWeight: FontWeight.w900)),
      ),
    );
  }

  // ---- Helpers ----
  String _shortBank(String name) {
    final m = RegExp(r'\(([^)]+)\)').firstMatch(name);
    if (m != null) return m.group(1)!;
    return name.isEmpty ? '' : name.split(' ').first;
  }

  String _formatAccount(String s) {
    final d = s.replaceAll(RegExp(r'\D'), '');
    if (d.length == 10) {
      return '${d.substring(0, 4)} ${d.substring(4, 7)} ${d.substring(7)}';
    }
    return s;
  }
}

/// Generic input bottom sheet used for account number / narration entry.
class _InputSheet extends StatelessWidget {
  final String title;
  final String hint;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;
  final ValueChanged<String> onDone;

  const _InputSheet({
    required this.title,
    required this.hint,
    required this.controller,
    this.keyboardType,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                height: 5,
                width: 46,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(title,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppColors.text)),
            const SizedBox(height: 14),
            Container(
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(AppRadius.md),
                boxShadow: AppShadow.soft,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: controller,
                autofocus: true,
                keyboardType: keyboardType,
                inputFormatters: inputFormatters,
                textCapitalization: textCapitalization,
                cursorColor: AppColors.primary,
                style: TextStyle(
                    fontWeight: FontWeight.w700, color: AppColors.text),
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: TextStyle(color: AppColors.muted),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.hero,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
                onPressed: () {
                  onDone(controller.text.trim());
                  Navigator.pop(context);
                },
                child: const Text('Done',
                    style: TextStyle(
                        color: Color(0xFF0A0A0C),
                        fontSize: 16,
                        fontWeight: FontWeight.w900)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Searchable bottom-sheet list of banks.
class _BankPickerSheet extends StatefulWidget {
  final List<_Bank> banks;
  final _Bank? selected;

  const _BankPickerSheet({required this.banks, this.selected});

  @override
  State<_BankPickerSheet> createState() => _BankPickerSheetState();
}

class _BankPickerSheetState extends State<_BankPickerSheet> {
  final searchController = TextEditingController();
  late List<_Bank> filtered = widget.banks;

  void _filter(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      filtered = q.isEmpty
          ? widget.banks
          : widget.banks
              .where((b) => b.name.toLowerCase().contains(q))
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
        height: MediaQuery.of(context).size.height * 0.75,
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
              child: Text('Select bank',
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
                textCapitalization: TextCapitalization.words,
                style: TextStyle(
                    fontWeight: FontWeight.w700, color: AppColors.text),
                decoration: InputDecoration(
                  hintText: 'Search bank',
                  hintStyle: TextStyle(color: AppColors.muted),
                  prefixIcon:
                      Icon(Icons.search_rounded, color: AppColors.muted),
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text('No banks found',
                          style: TextStyle(color: AppColors.muted)),
                    )
                  : ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) =>
                          Divider(height: 1, color: AppColors.border),
                      itemBuilder: (context, i) {
                        final bank = filtered[i];
                        final isSel = bank.code == widget.selected?.code;
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          onTap: () => Navigator.pop(context, bank),
                          leading: CircleAvatar(
                            backgroundColor: AppColors.primarySoft,
                            child: Text(
                              bank.name.isNotEmpty ? bank.name[0] : '?',
                              style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w900),
                            ),
                          ),
                          title: Text(bank.name,
                              style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.text)),
                          trailing: isSel
                              ? const Icon(Icons.check_circle_rounded,
                                  color: AppColors.success)
                              : null,
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

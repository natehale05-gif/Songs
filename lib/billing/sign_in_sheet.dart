import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import '../ui_kit.dart';
import 'auth_controller.dart';

/// Email sign-in, in two steps: address, then the code that arrives.
///
/// Returns true once a session exists.
Future<bool> showSignInSheet(
  BuildContext context,
  AppPalette palette,
  AuthController auth,
) async {
  final bool? ok = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: palette.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _SignInSheet(p: palette, auth: auth),
  );
  return ok ?? false;
}

class _SignInSheet extends StatefulWidget {
  const _SignInSheet({required this.p, required this.auth});

  final AppPalette p;
  final AuthController auth;

  @override
  State<_SignInSheet> createState() => _SignInSheetState();
}

class _SignInSheetState extends State<_SignInSheet> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _code = TextEditingController();
  bool _codeSent = false;
  bool _busy = false;
  String? _message;

  AppPalette get p => widget.p;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    final bool sent = await widget.auth.sendCode(_email.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _codeSent = sent;
      _message = widget.auth.message;
    });
  }

  Future<void> _verify() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    final bool ok = await widget.auth.verifyCode(_email.text, _code.text);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _busy = false;
      _message = widget.auth.message ?? 'That code was not accepted.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            20, 12, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: p.separator,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              _codeSent ? 'Enter your code' : 'Sign in',
              style: TextStyle(
                fontFamily: kDisplaySerif,
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: p.label,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _codeSent
                  ? 'We sent a six-digit code to ${_email.text.trim()}.'
                  : 'No password to remember — we email you a code. Your '
                      'address is used for signing in and for receipts, '
                      'nothing else.',
              style: TextStyle(fontSize: 14, height: 1.4, color: p.label2),
            ),
            const SizedBox(height: 16),
            if (!_codeSent)
              _field(
                controller: _email,
                hint: 'you@example.com',
                keyboardType: TextInputType.emailAddress,
                autofillHints: const <String>[AutofillHints.email],
              )
            else
              _field(
                controller: _code,
                hint: '123456',
                keyboardType: TextInputType.number,
                autofillHints: const <String>[AutofillHints.oneTimeCode],
                formatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
              ),
            if (_message != null) ...[
              const SizedBox(height: 10),
              Text(
                _message!,
                style: TextStyle(fontSize: 13, height: 1.35, color: p.label3),
              ),
            ],
            const SizedBox(height: 16),
            _primary(
              _busy
                  ? 'Working…'
                  : _codeSent
                      ? 'Continue'
                      : 'Email me a code',
              onTap: _busy ? null : (_codeSent ? _verify : _send),
            ),
            if (_codeSent) ...[
              const SizedBox(height: 6),
              Center(
                child: Pressable(
                  onTap: _busy
                      ? null
                      : () => setState(() {
                            _codeSent = false;
                            _code.clear();
                            _message = null;
                          }),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      'Use a different address',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: p.navy),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
    List<String>? autofillHints,
    List<TextInputFormatter>? formatters,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      autofillHints: autofillHints,
      inputFormatters: formatters,
      autocorrect: false,
      enableSuggestions: false,
      style: TextStyle(color: p.label, fontSize: 16),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: p.label4),
        filled: true,
        fillColor: p.fill1,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _primary(String label, {VoidCallback? onTap}) {
    return Pressable(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: onTap == null ? p.navy.withValues(alpha: 0.5) : p.navy,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(label,
              style: TextStyle(
                  color: p.navyText,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }
}

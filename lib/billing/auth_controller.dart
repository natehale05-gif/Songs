import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_config.dart';

/// Signing in, so a subscription can follow someone across their devices.
///
/// Email one-time codes rather than passwords: there is no password to leak or
/// reset, and it avoids asking a congregation to invent yet another one. It
/// also sidesteps Sign in with Apple, which is only obligatory when an app
/// offers third-party *social* login.
class AuthController extends ChangeNotifier {
  AuthController({SupabaseClient? client}) : _injected = client;

  final SupabaseClient? _injected;

  SupabaseClient get _client => _injected ?? Supabase.instance.client;

  /// Whether Supabase was initialised at all. False in builds with no
  /// credentials compiled in, and in tests that never set it up.
  static bool get available => billingConfigured;

  Session? get session => available ? _client.auth.currentSession : null;
  User? get user => available ? _client.auth.currentUser : null;
  bool get isSignedIn => session != null;
  String? get email => user?.email;

  /// The RevenueCat App User ID for this account.
  ///
  /// Deliberately the Supabase user id: it is what ties a purchase made in a
  /// browser to the same person signing in on a phone, which is the whole
  /// reason there is an account.
  String? get appUserId => user?.id;

  bool _busy = false;
  bool get busy => _busy;

  String? _message;
  String? get message => _message;

  /// Sends a six-digit code to [address]. Returns false if it could not be
  /// sent, with [message] explaining why.
  Future<bool> sendCode(String address) async {
    final String email = address.trim();
    if (!_looksLikeEmail(email)) {
      _message = 'That does not look like an email address.';
      notifyListeners();
      return false;
    }
    _busy = true;
    _message = null;
    notifyListeners();
    try {
      await _client.auth.signInWithOtp(email: email);
      _message = 'Check $email for a six-digit code.';
      return true;
    } on AuthException catch (error) {
      _message = error.message;
      return false;
    } catch (_) {
      _message = 'Could not reach the sign-in service. Check your connection.';
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Exchanges the emailed code for a session.
  Future<bool> verifyCode(String address, String code) async {
    _busy = true;
    _message = null;
    notifyListeners();
    try {
      await _client.auth.verifyOTP(
        email: address.trim(),
        token: code.trim(),
        type: OtpType.email,
      );
      return isSignedIn;
    } on AuthException catch (error) {
      _message = error.message;
      return false;
    } catch (_) {
      _message = 'Could not check that code. Try again.';
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    if (!available) return;
    try {
      await _client.auth.signOut();
    } catch (_) {
      // Even if the server call fails the local session is cleared, which is
      // what the person in front of the device asked for.
    }
    notifyListeners();
  }

  static bool _looksLikeEmail(String value) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
}

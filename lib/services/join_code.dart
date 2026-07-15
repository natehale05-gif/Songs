import 'dart:math';

/// Generates short, human friendly join codes for live sessions.
///
/// Ambiguous characters (0/O, 1/I/L) are intentionally omitted so codes are
/// easy to read aloud and type on a small screen.
class JoinCode {
  JoinCode._();

  static const String _alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

  /// Generates a random code of [length] characters (default 6).
  static String generate({int length = 6, Random? random}) {
    final Random rng = random ?? Random.secure();
    final StringBuffer buffer = StringBuffer();
    for (int i = 0; i < length; i++) {
      buffer.write(_alphabet[rng.nextInt(_alphabet.length)]);
    }
    return buffer.toString();
  }

  /// Normalises user input so that lower case letters and stray whitespace do
  /// not prevent a member from joining.
  static String normalize(String input) {
    return input.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');
  }

  /// Returns true when [input] could be a valid code for the given [length].
  static bool isValid(String input, {int length = 6}) {
    final String value = normalize(input);
    if (value.length != length) return false;
    return value.split('').every(_alphabet.contains);
  }
}

import 'dart:math';

/// Generates short, human friendly join codes. Ambiguous characters (0/O, 1/I/L)
/// are omitted so codes are easy to read aloud and type.
class JoinCode {
  JoinCode._();

  static const String _alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

  static String generate({int length = 6, Random? random}) {
    final Random rng = random ?? Random.secure();
    final StringBuffer buffer = StringBuffer();
    for (int i = 0; i < length; i++) {
      buffer.write(_alphabet[rng.nextInt(_alphabet.length)]);
    }
    return buffer.toString();
  }

  static String normalize(String input) =>
      input.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');

  static bool isValid(String input, {int length = 6}) {
    final String value = normalize(input);
    if (value.length != length) return false;
    return value.split('').every(_alphabet.contains);
  }
}

/// Heuristics for clipboard content that probably shouldn't sync silently.
class SensitiveGuard {
  static final _otp = RegExp(r'^\s*\d{4,8}\s*$');
  static final _card = RegExp(r'^[\d\s-]{13,23}$');
  static final _iban = RegExp(r'^[A-Z]{2}\d{2}[A-Z0-9]{11,30}$');
  static final _secretPrefix = RegExp(r'^(sk_live_|sk_test_|AKIA|ghp_|gho_|xox[bpa]-|eyJ[a-zA-Z0-9_-]{10,}\.)');
  static final _privKey = RegExp(r'-----BEGIN [A-Z ]*PRIVATE KEY-----');

  /// Returns a short human reason if [text] looks sensitive, else null.
  static String? check(String text) {
    final t = text.trim();
    if (t.isEmpty) return null;
    if (_privKey.hasMatch(t)) return 'a private key';
    if (_secretPrefix.hasMatch(t)) return 'an API key or token';
    if (_otp.hasMatch(t)) return 'a one-time code';
    if (_card.hasMatch(t) && _luhn(t.replaceAll(RegExp(r'\D'), ''))) return 'a card number';
    if (_iban.hasMatch(t.replaceAll(' ', ''))) return 'a bank account number';
    if (_looksLikePassword(t)) return 'a password';
    return null;
  }

  static bool _luhn(String digits) {
    if (digits.length < 13) return false;
    var sum = 0, alt = false;
    for (var i = digits.length - 1; i >= 0; i--) {
      var n = int.parse(digits[i]);
      if (alt) { n *= 2; if (n > 9) n -= 9; }
      sum += n; alt = !alt;
    }
    return sum % 10 == 0;
  }

  /// A generated-looking secret: mixed case AND digits AND (a symbol or long), no spaces,
  /// and not something that reads like a slug/identifier (all lowercase with dashes).
  static bool _looksLikePassword(String t) {
    if (t.length < 10 || t.length > 64 || t.contains(RegExp(r'[\s/.@]'))) return false;
    final lower = RegExp(r'[a-z]').hasMatch(t), upper = RegExp(r'[A-Z]').hasMatch(t);
    final digit = RegExp(r'\d').hasMatch(t), symbol = RegExp(r'[^a-zA-Z0-9_-]').hasMatch(t);
    if (!(lower && upper && digit)) return false;
    return symbol || t.length >= 16;
  }
}

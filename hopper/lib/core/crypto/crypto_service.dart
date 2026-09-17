import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// All cryptography in one place.
///
/// Identity: Ed25519 keypair per device (long-lived).
/// Session:  X25519 ephemeral key agreement, authenticated by Ed25519 signatures,
///           HKDF-SHA256 → 256-bit key, XChaCha20-Poly1305 per frame.
class CryptoService {
  static final _ed = Ed25519();
  static final _x = X25519();
  static final _aead = Xchacha20.poly1305Aead();
  static final _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
  static final _rng = Random.secure();

  static Uint8List randomBytes(int n) => Uint8List.fromList(List.generate(n, (_) => _rng.nextInt(256)));

  static Future<SimpleKeyPair> generateIdentity() => _ed.newKeyPair();

  static Future<Uint8List> publicKeyBytes(SimpleKeyPair kp) async =>
      Uint8List.fromList((await kp.extractPublicKey()).bytes);

  static Future<Uint8List> privateKeyBytes(SimpleKeyPair kp) async =>
      Uint8List.fromList(await kp.extractPrivateKeyBytes());

  static SimpleKeyPair identityFromBytes(Uint8List sk, Uint8List pk) =>
      SimpleKeyPairData(sk, publicKey: SimplePublicKey(pk, type: KeyPairType.ed25519), type: KeyPairType.ed25519);

  static Future<Uint8List> sign(SimpleKeyPair identity, List<int> msg) async =>
      Uint8List.fromList((await _ed.sign(msg, keyPair: identity)).bytes);

  static Future<bool> verify(Uint8List pk, List<int> msg, Uint8List sig) => _ed.verify(
        msg,
        signature: Signature(sig, publicKey: SimplePublicKey(pk, type: KeyPairType.ed25519)),
      );

  // ---- session ----
  static Future<SimpleKeyPair> newEphemeral() => _x.newKeyPair();

  static Future<Uint8List> ephemeralPublic(SimpleKeyPair kp) async =>
      Uint8List.fromList((await kp.extractPublicKey()).bytes);

  /// Derive the shared session key. The salt binds the key to this handshake
  /// (both ephemeral public keys, sorted, so both sides compute the same value).
  static Future<SecretKey> deriveSessionKey(SimpleKeyPair myEph, Uint8List theirEphPk, Uint8List myEphPk) async {
    final shared = await _x.sharedSecretKey(
      keyPair: myEph,
      remotePublicKey: SimplePublicKey(theirEphPk, type: KeyPairType.x25519),
    );
    final a = base64Encode(myEphPk), b = base64Encode(theirEphPk);
    final salt = utf8.encode(a.compareTo(b) < 0 ? '$a|$b' : '$b|$a');
    return _hkdf.deriveKey(secretKey: shared, nonce: salt, info: utf8.encode('hopper-session-v1'));
  }

  /// Returns nonce(24) || ciphertext || mac(16)
  static Future<Uint8List> encrypt(SecretKey key, List<int> plaintext) async {
    final nonce = randomBytes(24);
    final box = await _aead.encrypt(plaintext, secretKey: key, nonce: nonce);
    return Uint8List.fromList([...nonce, ...box.cipherText, ...box.mac.bytes]);
  }

  static Future<Uint8List> decrypt(SecretKey key, Uint8List blob) async {
    if (blob.length < 40) throw const FormatException('ciphertext too short');
    final nonce = blob.sublist(0, 24);
    final mac = blob.sublist(blob.length - 16);
    final ct = blob.sublist(24, blob.length - 16);
    final clear = await _aead.decrypt(SecretBox(ct, nonce: nonce, mac: Mac(mac)), secretKey: key);
    return Uint8List.fromList(clear);
  }

  static Future<String> sha256Hex(List<int> data) async {
    final h = await Sha256().hash(data);
    return h.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// HMAC-SHA256 used as the pairing proof: proves the scanner saw the QR/code.
  static Future<Uint8List> hmac(List<int> key, List<int> msg) async {
    final mac = await Hmac.sha256().calculateMac(msg, secretKey: SecretKey(key));
    return Uint8List.fromList(mac.bytes);
  }

  static bool constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var r = 0;
    for (var i = 0; i < a.length; i++) { r |= a[i] ^ b[i]; }
    return r == 0;
  }
}

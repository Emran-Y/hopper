import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:uuid/uuid.dart';

import '../storage/local_store.dart';
import 'crypto/crypto_service.dart';

/// This device's long-lived identity.
class Identity {
  final String id;
  final SimpleKeyPair keyPair;
  final Uint8List publicKey;

  Identity._(this.id, this.keyPair, this.publicKey);

  /// A throw-away identity (used by tests and never persisted).
  static Future<Identity> ephemeral() async {
    final kp = await CryptoService.generateIdentity();
    return Identity._(const Uuid().v4(), kp, await CryptoService.publicKeyBytes(kp));
  }

  static Future<Identity> loadOrCreate(LocalStore store) async {
    final existing = await store.loadIdentity();
    if (existing != null) {
      final (sk, pk, id) = existing;
      return Identity._(id, CryptoService.identityFromBytes(sk, pk), pk);
    }
    final kp = await CryptoService.generateIdentity();
    final pk = await CryptoService.publicKeyBytes(kp);
    final sk = await CryptoService.privateKeyBytes(kp);
    final id = const Uuid().v4();
    await store.saveIdentity(sk, pk, id);
    return Identity._(id, kp, pk);
  }

  static String get platformName {
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    if (Platform.isWindows) return 'windows';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isLinux) return 'linux';
    return 'unknown';
  }

  static String get defaultDeviceName {
    try {
      final h = Platform.localHostname;
      if (h.isNotEmpty && h != 'localhost') return h;
    } catch (_) {}
    return switch (platformName) {
      'android' => 'Android phone',
      'ios' => 'iPhone',
      'windows' => 'Windows PC',
      'macos' => 'Mac',
      'linux' => 'Linux PC',
      _ => 'Hopper device',
    };
  }
}

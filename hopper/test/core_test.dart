import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hopper/core/app_controller.dart';
import 'package:hopper/core/crypto/crypto_service.dart';
import 'package:hopper/core/models/models.dart';
import 'package:hopper/core/protocol/frames.dart';
import 'package:hopper/core/sensitive_guard.dart';

void main() {
  group('framing', () {
    test('CBOR round-trip with bytes, strings, ints, bools, nulls', () {
      final m = {'t': 'CLIP', 'n': 42, 'ok': true, 'x': null, 'data': Uint8List.fromList([1, 2, 3]), 'list': ['a', 'b']};
      final out = Frames.decode(Frames.encode(m));
      expect(out['t'], 'CLIP');
      expect(out['n'], 42);
      expect(out['ok'], true);
      expect(out['x'], isNull);
      expect(out['data'], Uint8List.fromList([1, 2, 3]));
      expect(out['list'], ['a', 'b']);
    });

    test('length-prefixed reader reassembles split and coalesced frames', () {
      final r = LengthPrefixedReader();
      final a = LengthPrefixedReader.wrap(Uint8List.fromList(utf8.encode('hello')));
      final b = LengthPrefixedReader.wrap(Uint8List.fromList(utf8.encode('world!')));
      final all = [...a, ...b];
      final got = <String>[];
      // feed in awkward chunk sizes
      for (var i = 0; i < all.length; i += 3) {
        for (final f in r.feed(all.sublist(i, (i + 3).clamp(0, all.length)))) {
          got.add(utf8.decode(f));
        }
      }
      expect(got, ['hello', 'world!']);
    });
  });

  group('crypto', () {
    test('two parties derive the same session key and can talk', () async {
      final ea = await CryptoService.newEphemeral(), eb = await CryptoService.newEphemeral();
      final pa = await CryptoService.ephemeralPublic(ea), pb = await CryptoService.ephemeralPublic(eb);
      final ka = await CryptoService.deriveSessionKey(ea, pb, pa);
      final kb = await CryptoService.deriveSessionKey(eb, pa, pb);
      final ct = await CryptoService.encrypt(ka, utf8.encode('secret clip'));
      expect(utf8.decode(await CryptoService.decrypt(kb, ct)), 'secret clip');
    });

    test('tampered ciphertext fails', () async {
      final ea = await CryptoService.newEphemeral(), eb = await CryptoService.newEphemeral();
      final pa = await CryptoService.ephemeralPublic(ea), pb = await CryptoService.ephemeralPublic(eb);
      final ka = await CryptoService.deriveSessionKey(ea, pb, pa);
      final ct = await CryptoService.encrypt(ka, utf8.encode('x'));
      ct[30] ^= 0xFF;
      expect(() => CryptoService.decrypt(ka, ct), throwsA(anything));
    });

    test('identity signature verifies', () async {
      final id = await CryptoService.generateIdentity();
      final pk = await CryptoService.publicKeyBytes(id);
      final sig = await CryptoService.sign(id, [1, 2, 3]);
      expect(await CryptoService.verify(pk, [1, 2, 3], sig), isTrue);
      expect(await CryptoService.verify(pk, [1, 2, 4], sig), isFalse);
    });
  });

  group('pairing payload', () {
    test('QR payload round-trips', () {
      final info = PairingInfo(code: '123456', hostId: 'abc', hostName: 'PC', hostPlatform: 'linux',
          hostPk: Uint8List.fromList(List.generate(32, (i) => i)), hosts: ['192.168.1.2'], port: 47331,
          expiresAt: DateTime.now());
      final parsed = PairingInfo.parse(info.toQrPayload())!;
      expect(parsed.code, '123456');
      expect(parsed.hostName, 'PC');
      expect(parsed.hosts, ['192.168.1.2']);
      expect(parsed.hostPk, info.hostPk);
      expect(PairingInfo.parse('https://example.com'), isNull);
    });
  });

  group('rules', () {
    test('direction semantics and mirroring', () {
      expect(SyncDirection.toPeer.allowsSend, isTrue);
      expect(SyncDirection.toPeer.allowsReceive, isFalse);
      expect(SyncDirection.toPeer.mirrored, SyncDirection.fromPeer);
      expect(SyncDirection.manual.allowsSend, isFalse);
      expect(SyncDirection.twoWay.mirrored, SyncDirection.twoWay);
    });
    test('link detection', () {
      expect(Clip.looksLikeLink('https://example.com/a?b=1'), isTrue);
      expect(Clip.looksLikeLink('hello world'), isFalse);
    });
  });

  group('sensitive guard', () {
    test('flags OTPs, cards, tokens; passes normal text', () {
      expect(SensitiveGuard.check('482913'), 'a one-time code');
      expect(SensitiveGuard.check('4111 1111 1111 1111'), 'a card number');
      expect(SensitiveGuard.check('sk_live_abcdefghijklmnop'), 'an API key or token');
      expect(SensitiveGuard.check('Meeting moved to 3pm, room B'), isNull);
      // identifiers, slugs and file names are not passwords
      expect(SensitiveGuard.check('hopper-text-1789650677'), isNull);
      expect(SensitiveGuard.check('my_project_v2_final'), isNull);
      expect(SensitiveGuard.check('Screenshot 2026-09-17'), isNull);
      // generated-looking secrets are
      expect(SensitiveGuard.check('xK9#pQ2mL!vR'), 'a password');
      expect(SensitiveGuard.check('Tr0ub4dorAndHorseBattery'), 'a password');
      expect(SensitiveGuard.check('https://github.com/hopper/app/pull/42'), isNull);
    });
  });
}

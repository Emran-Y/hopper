import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hopper/core/crypto/crypto_service.dart';
import 'package:hopper/core/identity.dart';
import 'package:hopper/core/protocol/frames.dart';
import 'package:hopper/core/transport/lan_transport.dart';

void main() {
  test('two devices handshake over loopback, verify identities, pair and exchange an encrypted clip', () async {
    final a = await Identity.ephemeral(), b = await Identity.ephemeral();
    final ta = LanTransport(a, () => 'PC');
    final tb = LanTransport(b, () => 'Phone');
    await ta.start();

    // A (host) accepts, B (joiner) dials.
    final accepted = ta.incoming.first;
    final connB = await tb.connect('127.0.0.1', ta.port);
    final connA = await accepted;
    final helloAtB = connB.handshake();
    final helloAtA = connA.handshake();
    final hb = await helloAtB, ha = await helloAtA;

    expect(hb.id, a.id);
    expect(hb.identityPk, a.publicKey);
    expect(ha.id, b.id);
    expect(ha.name, 'Phone');

    // Pairing proof: B proves it knows the 6-digit code.
    const code = '123456';
    final proof = await CryptoService.hmac(utf8.encode(code), [...b.publicKey, ...a.publicKey]);
    final gotPair = connA.frames.firstWhere((f) => f['t'] == FrameType.pairRequest);
    await connB.send({'t': FrameType.pairRequest, 'proof': proof});
    final req = await gotPair;
    final expected = await CryptoService.hmac(utf8.encode(code), [...ha.identityPk, ...a.publicKey]);
    expect(CryptoService.constantTimeEquals(req['proof'] as List<int>, expected), isTrue);

    // Encrypted clip A → B.
    final gotClip = connB.frames.firstWhere((f) => f['t'] == FrameType.clip);
    await connA.send({'t': FrameType.clip, 'id': 'c1', 'type': 'text', 'text': 'hello from PC', 'manual': false});
    final clip = await gotClip;
    expect(clip['text'], 'hello from PC');

    connA.close(); connB.close();
    await ta.stop();
  });
}

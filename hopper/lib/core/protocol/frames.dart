import 'dart:typed_data';

import 'package:cbor/cbor.dart';

/// Frame types on the wire (v1).
class FrameType {
  static const hello = 'HELLO';
  static const helloAck = 'HELLO_ACK';
  static const pairRequest = 'PAIR_REQUEST';
  static const pairOk = 'PAIR_OK';
  static const pairFail = 'PAIR_FAIL';
  static const ping = 'PING';
  static const pong = 'PONG';
  static const clip = 'CLIP';
  static const clipAck = 'CLIP_ACK';
  static const rulesSync = 'RULES_SYNC';
  static const unpair = 'UNPAIR';
}

const protocolVersion = 1;

/// A frame is a CBOR map. Encoding/decoding helpers.
class Frames {
  static Uint8List encode(Map<String, Object?> m) {
    final map = <CborValue, CborValue>{};
    m.forEach((k, v) => map[CborString(k)] = _toCbor(v));
    return Uint8List.fromList(cbor.encode(CborMap(map)));
  }

  static Map<String, Object?> decode(Uint8List bytes) {
    final v = cbor.decode(bytes);
    if (v is! CborMap) throw const FormatException('frame is not a map');
    final out = <String, Object?>{};
    v.forEach((k, val) => out[(k as CborString).toString()] = _fromCbor(val));
    return out;
  }

  static CborValue _toCbor(Object? v) {
    if (v == null) return const CborNull();
    if (v is Uint8List) return CborBytes(v);
    if (v is String) return CborString(v);
    if (v is bool) return CborBool(v);
    if (v is int) return CborSmallInt(v);
    if (v is double) return CborFloat(v);
    if (v is Map) {
      final m = <CborValue, CborValue>{};
      v.forEach((k, val) => m[CborString(k.toString())] = _toCbor(val));
      return CborMap(m);
    }
    if (v is List<int>) return CborBytes(v);
    if (v is List) return CborList(v.map(_toCbor).toList());
    return CborString(v.toString());
  }

  static Object? _fromCbor(CborValue v) {
    if (v is CborNull) return null;
    if (v is CborBytes) return Uint8List.fromList(v.bytes);
    if (v is CborString) return v.toString();
    if (v is CborBool) return v.value;
    if (v is CborInt) return v.toInt();
    if (v is CborFloat) return v.value;
    if (v is CborMap) {
      final m = <String, Object?>{};
      v.forEach((k, val) => m[k.toString()] = _fromCbor(val));
      return m;
    }
    if (v is CborList) return v.map(_fromCbor).toList();
    return v.toString();
  }
}

/// Length-prefixed framing over a byte stream: [u32 BE length][payload].
class LengthPrefixedReader {
  final _buf = BytesBuilder(copy: false);
  final int maxFrame;
  LengthPrefixedReader({this.maxFrame = 256 * 1024 * 1024});

  /// Feed bytes; returns every complete frame now available.
  List<Uint8List> feed(List<int> data) {
    _buf.add(data);
    final out = <Uint8List>[];
    final bytes = _buf.toBytes();
    var offset = 0;
    while (bytes.length - offset >= 4) {
      final len = ByteData.sublistView(bytes, offset, offset + 4).getUint32(0);
      if (len > maxFrame) throw const FormatException('frame too large');
      if (bytes.length - offset - 4 < len) break;
      out.add(Uint8List.fromList(bytes.sublist(offset + 4, offset + 4 + len)));
      offset += 4 + len;
    }
    _buf.clear();
    if (offset < bytes.length) _buf.add(bytes.sublist(offset));
    return out;
  }

  static Uint8List wrap(Uint8List payload) {
    final b = ByteData(4)..setUint32(0, payload.length);
    return Uint8List.fromList([...b.buffer.asUint8List(), ...payload]);
  }
}

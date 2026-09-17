import 'dart:convert';
import 'dart:typed_data';

/// Which way clips are allowed to flow for a given paired device.
enum SyncDirection { twoWay, toPeer, fromPeer, manual }

extension SyncDirectionX on SyncDirection {
  String get label => switch (this) {
        SyncDirection.twoWay => 'Two-way',
        SyncDirection.toPeer => 'This device → peer only',
        SyncDirection.fromPeer => 'Peer → this device only',
        SyncDirection.manual => 'Manual',
      };
  String get description => switch (this) {
        SyncDirection.twoWay => 'Clips flow automatically in both directions.',
        SyncDirection.toPeer => 'Only what you copy here is sent to the peer.',
        SyncDirection.fromPeer => 'Only what the peer copies arrives here.',
        SyncDirection.manual => 'Nothing automatic. Push clips by hand.',
      };
  /// May this device automatically send to the peer?
  bool get allowsSend => this == SyncDirection.twoWay || this == SyncDirection.toPeer;
  /// May this device accept automatic clips from the peer?
  bool get allowsReceive => this == SyncDirection.twoWay || this == SyncDirection.fromPeer;

  /// The same rule as seen from the other device.
  SyncDirection get mirrored => switch (this) {
        SyncDirection.toPeer => SyncDirection.fromPeer,
        SyncDirection.fromPeer => SyncDirection.toPeer,
        _ => this,
      };
}

enum ClipType { text, link, image, file }

class PairRules {
  SyncDirection direction;
  bool allowText;
  bool allowLinks;
  bool allowImages;
  bool allowFiles;
  bool notify;
  int maxSizeBytes;   // images
  int maxFileBytes;   // files

  PairRules({
    this.direction = SyncDirection.twoWay,
    this.allowText = true,
    this.allowLinks = true,
    this.allowImages = true,
    this.allowFiles = true,
    this.notify = true,
    this.maxSizeBytes = 25 * 1024 * 1024,
    this.maxFileBytes = 50 * 1024 * 1024,
  });

  bool allows(ClipType t) => switch (t) {
        ClipType.text => allowText,
        ClipType.link => allowLinks,
        ClipType.image => allowImages,
        ClipType.file => allowFiles,
      };

  /// Size cap that applies to a clip of this type (text is never capped here).
  int capFor(ClipType t) => switch (t) {
        ClipType.image => maxSizeBytes,
        ClipType.file => maxFileBytes,
        _ => 1 << 30,
      };

  Map<String, dynamic> toJson() => {
        'direction': direction.name,
        'allowText': allowText,
        'allowLinks': allowLinks,
        'allowImages': allowImages,
        'allowFiles': allowFiles,
        'notify': notify,
        'maxSizeBytes': maxSizeBytes,
        'maxFileBytes': maxFileBytes,
      };

  factory PairRules.fromJson(Map<String, dynamic> j) => PairRules(
        direction: SyncDirection.values.firstWhere((d) => d.name == j['direction'], orElse: () => SyncDirection.twoWay),
        allowText: j['allowText'] ?? true,
        allowLinks: j['allowLinks'] ?? true,
        allowImages: j['allowImages'] ?? true,
        allowFiles: j['allowFiles'] ?? true,
        notify: j['notify'] ?? true,
        maxSizeBytes: j['maxSizeBytes'] ?? 25 * 1024 * 1024,
        maxFileBytes: j['maxFileBytes'] ?? 50 * 1024 * 1024,
      );
}

/// A paired (trusted) device.
class Peer {
  final String id;
  String name;
  String platform;
  final Uint8List identityPk; // Ed25519 public key
  final DateTime pairedAt;
  DateTime? lastSeenAt;
  PairRules rules;

  Peer({
    required this.id,
    required this.name,
    required this.platform,
    required this.identityPk,
    required this.pairedAt,
    this.lastSeenAt,
    PairRules? rules,
  }) : rules = rules ?? PairRules();

  String get fingerprint => fingerprintOf(identityPk);

  static String fingerprintOf(Uint8List pk) {
    final b = pk.sublist(0, 6);
    return b.map((x) => x.toRadixString(16).padLeft(2, '0')).join().toUpperCase();
  }

  static const _emoji = ['🦊','🌊','🎸','🍋','🚀','🌵','🐙','🍕','🎈','🦋','⚡','🍀','🐬','🎯','🌙','🔥',
    '🐸','🍓','🎲','🦄','🌸','🐢','🎹','🍩','🛸','🧩','🐝','🍒','🎨','🦜','🌈','🧭'];

  /// Four emoji derived from both keys — shown on both devices after pairing.
  static String emojiCheck(Uint8List a, Uint8List b) {
    final sa = base64Encode(a), sb = base64Encode(b);
    final lo = sa.compareTo(sb) <= 0 ? a : b;
    final hi = identical(lo, a) ? b : a;
    var h = 2166136261;
    for (final v in [...lo, ...hi]) { h ^= v; h = (h * 16777619) & 0xFFFFFFFF; }
    final out = <String>[];
    for (var i = 0; i < 4; i++) { out.add(_emoji[(h >> (i * 5)) & 31]); }
    return out.join(' ');
  }

  Map<String, dynamic> toJson() => {
        'id': id, 'name': name, 'platform': platform,
        'identityPk': base64Encode(identityPk),
        'pairedAt': pairedAt.toIso8601String(),
        'lastSeenAt': lastSeenAt?.toIso8601String(),
        'rules': rules.toJson(),
      };

  factory Peer.fromJson(Map<String, dynamic> j) => Peer(
        id: j['id'], name: j['name'], platform: j['platform'] ?? 'unknown',
        identityPk: base64Decode(j['identityPk']),
        pairedAt: DateTime.parse(j['pairedAt']),
        lastSeenAt: j['lastSeenAt'] != null ? DateTime.parse(j['lastSeenAt']) : null,
        rules: PairRules.fromJson(Map<String, dynamic>.from(j['rules'] ?? {})),
      );
}

/// One clipboard item.
class Clip {
  final String id;
  final ClipType type;
  final String? text;      // text / link
  Uint8List? bytes;        // image or file bytes (in memory or loaded from disk)
  String? blobPath;        // where the bytes live on disk (history)
  final String? name;      // file name (files; images may have one too)
  final String? mime;
  final int byteLength;    // size of [bytes] even after they were dropped from memory
  final String originId;   // device that created it
  final String originName;
  final DateTime createdAt;
  final String sha256Hex;
  bool pinned;
  final Map<String, String> delivery = {}; // peerId -> state

  Clip({
    required this.id, required this.type, this.text, this.bytes, this.blobPath, this.name, this.mime,
    int? byteLength,
    required this.originId, required this.originName, required this.createdAt,
    required this.sha256Hex, this.pinned = false,
  }) : byteLength = byteLength ?? bytes?.length ?? 0;

  int get size => bytes?.length ?? (byteLength > 0 ? byteLength : utf8.encode(text ?? '').length);

  String get preview => switch (type) {
        ClipType.image => '${name ?? 'Image'} · ${fmtSize(size)}',
        ClipType.file => '${name ?? 'File'} · ${fmtSize(size)}',
        _ => (text ?? '').replaceAll('\n', ' ').trim(),
      };

  static String fmtSize(int b) => b > 1024 * 1024
      ? '${(b / 1048576).toStringAsFixed(1)} MB'
      : b > 1024 ? '${(b / 1024).toStringAsFixed(0)} KB' : '$b B';

  static bool looksLikeLink(String s) {
    final t = s.trim();
    if (t.contains(RegExp(r'\s'))) return false;
    return RegExp(r'^(https?://|www\.)[^\s]+$', caseSensitive: false).hasMatch(t);
  }

  Map<String, dynamic> toJson() => {
        'id': id, 'type': type.name, 'text': text, 'imagePath': blobPath, 'name': name, 'mime': mime,
        'byteLength': byteLength,
        'originId': originId, 'originName': originName,
        'createdAt': createdAt.toIso8601String(), 'sha256': sha256Hex, 'pinned': pinned,
        'delivery': delivery,
      };

  factory Clip.fromJson(Map<String, dynamic> j) {
    final c = Clip(
      id: j['id'], type: ClipType.values.firstWhere((t) => t.name == j['type'], orElse: () => ClipType.text),
      text: j['text'], blobPath: j['imagePath'], name: j['name'], mime: j['mime'],
      byteLength: j['byteLength'] ?? 0,
      originId: j['originId'], originName: j['originName'] ?? '',
      createdAt: DateTime.parse(j['createdAt']), sha256Hex: j['sha256'], pinned: j['pinned'] ?? false,
    );
    c.delivery.addAll(Map<String, String>.from(j['delivery'] ?? {}));
    return c;
  }
}

class AppSettings {
  String deviceName;
  bool paused;
  bool onboardingDone;
  bool startMinimized;
  bool sensitiveGuard;
  int historyLimit;
  String theme; // system | light | dark

  AppSettings({
    required this.deviceName,
    this.paused = false,
    this.onboardingDone = false,
    this.startMinimized = false,
    this.sensitiveGuard = true,
    this.historyLimit = 200,
    this.theme = 'system',
  });

  Map<String, dynamic> toJson() => {
        'deviceName': deviceName, 'paused': paused, 'onboardingDone': onboardingDone,
        'startMinimized': startMinimized, 'sensitiveGuard': sensitiveGuard, 'historyLimit': historyLimit,
        'theme': theme,
      };
  factory AppSettings.fromJson(Map<String, dynamic> j, String fallbackName) => AppSettings(
        deviceName: j['deviceName'] ?? fallbackName, paused: j['paused'] ?? false,
        onboardingDone: j['onboardingDone'] ?? false, startMinimized: j['startMinimized'] ?? false,
        sensitiveGuard: j['sensitiveGuard'] ?? true, historyLimit: j['historyLimit'] ?? 200,
        theme: j['theme'] ?? 'system',
      );
}

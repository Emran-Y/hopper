import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import '../core/models/models.dart';

/// Plain-file JSON storage under the app's private data directory.
///
/// MVP note: the identity secret key is stored as a file with restricted
/// permissions. v1.0 moves it into the OS keystore (see docs/ROADMAP).
class LocalStore {
  late final Directory root;
  late final Directory imagesDir;

  Future<void> init() async {
    final base = await getApplicationSupportDirectory();
    root = Directory('${base.path}${Platform.pathSeparator}hopper');
    imagesDir = Directory('${root.path}${Platform.pathSeparator}images');
    await imagesDir.create(recursive: true);
  }

  File _f(String name) => File('${root.path}${Platform.pathSeparator}$name');

  Future<Map<String, dynamic>?> _readJson(String name) async {
    final f = _f(name);
    if (!await f.exists()) return null;
    try {
      return jsonDecode(await f.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeJson(String name, Object data) async {
    final f = _f(name);
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(jsonEncode(data), flush: true);
    await tmp.rename(f.path);
  }

  // ---- identity ----
  Future<(Uint8List sk, Uint8List pk, String id)?> loadIdentity() async {
    final j = await _readJson('identity.json');
    if (j == null) return null;
    return (base64Decode(j['sk']), base64Decode(j['pk']), j['id'] as String);
  }

  Future<void> saveIdentity(Uint8List sk, Uint8List pk, String id) async {
    await _writeJson('identity.json', {'sk': base64Encode(sk), 'pk': base64Encode(pk), 'id': id});
    if (!Platform.isWindows) {
      try { await Process.run('chmod', ['600', _f('identity.json').path]); } catch (_) {}
    }
  }

  // ---- settings ----
  Future<AppSettings> loadSettings(String fallbackName) async =>
      AppSettings.fromJson(await _readJson('settings.json') ?? {}, fallbackName);

  Future<void> saveSettings(AppSettings s) => _writeJson('settings.json', s.toJson());

  // ---- peers ----
  Future<List<Peer>> loadPeers() async {
    final j = await _readJson('peers.json');
    if (j == null) return [];
    return (j['peers'] as List).map((e) => Peer.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<void> savePeers(List<Peer> peers) =>
      _writeJson('peers.json', {'peers': peers.map((p) => p.toJson()).toList()});

  // ---- history ----
  Future<List<Clip>> loadHistory() async {
    final j = await _readJson('history.json');
    if (j == null) return [];
    return (j['clips'] as List).map((e) => Clip.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<void> saveHistory(List<Clip> clips) =>
      _writeJson('history.json', {'clips': clips.map((c) => c.toJson()).toList()});

  Future<String> saveImage(String clipId, Uint8List png) => saveBlob(clipId, png, 'png');

  /// Store image/file bytes for a history item; returns the path.
  Future<String> saveBlob(String clipId, Uint8List bytes, String ext) async {
    final safeExt = ext.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    final f = File('${imagesDir.path}${Platform.pathSeparator}$clipId.${safeExt.isEmpty ? 'bin' : safeExt}');
    await f.writeAsBytes(bytes, flush: true);
    return f.path;
  }

  Future<Uint8List?> loadImage(String? path) async {
    if (path == null) return null;
    final f = File(path);
    return await f.exists() ? await f.readAsBytes() : null;
  }

  Future<void> deleteImage(String? path) async {
    if (path == null) return;
    try { await File(path).delete(); } catch (_) {}
  }
}

import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:path_provider/path_provider.dart';

import 'android_bridge.dart';

/// What is on the clipboard right now: text, an image, or a file.
class ClipboardContent {
  final String? text;
  final Uint8List? imagePng;   // image bytes (PNG on desktop; whatever [mime] says elsewhere)
  final Uint8List? fileBytes;  // a file copied in Finder / shared from the phone
  final String? fileName;
  final String? mime;
  final String? filePath;      // where a received file was saved (desktop)
  final bool sensitive;        // flagged by the OS (Android "sensitive" clips)

  ClipboardContent({this.text, this.imagePng, this.fileBytes, this.fileName, this.mime, this.filePath, this.sensitive = false});

  bool get isEmpty => (text == null || text!.trim().isEmpty) && imagePng == null && fileBytes == null;
  bool get isFile => fileBytes != null;
  bool get isImage => imagePng != null;

  factory ClipboardContent.fromNative(Map<String, dynamic> m) {
    final bytes = m['bytes'] is Uint8List ? m['bytes'] as Uint8List : null;
    final type = m['type']?.toString();
    return ClipboardContent(
      text: type == 'text' ? m['text']?.toString() : null,
      imagePng: type == 'image' ? bytes : null,
      fileBytes: type == 'file' ? bytes : null,
      fileName: m['name']?.toString(),
      mime: m['mime']?.toString(),
      sensitive: m['sensitive'] == true,
    );
  }
}

/// Reads and writes the OS clipboard, and (on desktop) watches for changes.
///
/// Desktop: polls every 400 ms — macOS has no change notification API at all,
/// and polling text + image + file list is cheap.
/// Android: reads/writes go through native code (works with no window open); the
/// native service pushes clipboard changes to us, [changes] never fires here.
/// iOS: reads only when the app is active (the OS forbids everything else).
class ClipboardService {
  static bool get isDesktop => Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  /// iOS shows a system banner (and on iOS 16+ a permission prompt) every time an
  /// app reads the pasteboard; Android 12+ shows a toast. Only read on purpose there.
  static bool get readsAreNoisy => Platform.isIOS || Platform.isAndroid;

  static const maxFileBytes = 100 * 1024 * 1024;

  final _changes = StreamController<ClipboardContent>.broadcast();
  Stream<ClipboardContent> get changes => _changes.stream;

  Timer? _timer;
  String? _lastText;
  int? _lastImageLen;
  String? _lastFiles;
  int? _lastChangeCount; // macOS NSPasteboard.changeCount
  DateTime _suppressUntil = DateTime.fromMillisecondsSinceEpoch(0);
  static const _mac = MethodChannel('hopper/mac');

  /// macOS: the pasteboard's change counter (increments on every write). Null elsewhere.
  Future<int?> _macChangeCount() async {
    if (!Platform.isMacOS) return null;
    try { return await _mac.invokeMethod<int>('changeCount'); } catch (_) { return null; }
  }

  void startWatching() {
    if (!isDesktop || _timer != null) return;
    _timer = Timer.periodic(const Duration(milliseconds: 400), (_) => _poll());
  }

  void stopWatching() {
    _timer?.cancel();
    _timer = null;
  }

  bool _polling = false;
  Future<void> _poll() async {
    if (_polling) return;
    _polling = true;
    try {
      // macOS: only look at the contents when the pasteboard's change counter moved.
      // Re-reading an image re-encodes it to different bytes each time, which used to
      // look like a brand-new clip on every poll.
      final cc = await _macChangeCount();
      if (cc != null) {
        if (cc == _lastChangeCount) return;
        _lastChangeCount = cc;
      }
      final files = await _desktopFiles();
      final filesKey = files.join('|');
      String? text;
      Uint8List? image;
      if (files.isEmpty) {
        try { text = (await Clipboard.getData(Clipboard.kTextPlain))?.text; } catch (_) {}
        try { image = await Pasteboard.image; } catch (_) {}
      }
      if (DateTime.now().isBefore(_suppressUntil)) {
        _lastText = text; _lastImageLen = image?.length; _lastFiles = filesKey;
        return;
      }
      final filesChanged = files.isNotEmpty && filesKey != _lastFiles;
      final textChanged = text != null && text.isNotEmpty && text != _lastText;
      final imageChanged = image != null && image.length != _lastImageLen;
      if (filesChanged) {
        _lastFiles = filesKey; _lastText = null; _lastImageLen = null;
        final c = await _readFile(files.first);
        if (c != null) _changes.add(c);
      } else if (textChanged || imageChanged) {
        _lastText = text; _lastImageLen = image?.length; _lastFiles = filesKey;
        // Prefer the image when both changed (e.g. screenshot with alt text).
        _changes.add(imageChanged ? ClipboardContent(imagePng: image, mime: 'image/png') : ClipboardContent(text: text));
      }
    } catch (_) {
      // Clipboard can be momentarily locked by another app; ignore.
    } finally {
      _polling = false;
    }
  }

  Future<List<String>> _desktopFiles() async {
    if (!isDesktop) return const [];
    try {
      final f = await Pasteboard.files();
      return f.where((p) => p.isNotEmpty && FileSystemEntity.isFileSync(p)).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<ClipboardContent?> _readFile(String path) async {
    try {
      final f = File(path);
      final len = await f.length();
      if (len > maxFileBytes) return null;
      final bytes = await f.readAsBytes();
      final name = path.split(Platform.pathSeparator).last;
      final mime = mimeFor(name);
      if (mime.startsWith('image/') && mime != 'image/heic') {
        // An image file copied in Finder: send it as an image so it lands on the other
        // device's clipboard (and in its gallery), not as a download.
        return ClipboardContent(imagePng: bytes, fileName: name, mime: mime, filePath: path);
      }
      return ClipboardContent(fileBytes: bytes, fileName: name, mime: mime, filePath: path);
    } catch (_) {
      return null;
    }
  }

  /// Current clipboard contents (desktop + Android: files/images/text; iOS: image/text).
  Future<ClipboardContent> read() async {
    if (Platform.isAndroid) return await AndroidBridge.read() ?? ClipboardContent();
    if (isDesktop) {
      final files = await _desktopFiles();
      if (files.isNotEmpty) {
        final c = await _readFile(files.first);
        if (c != null) return c;
      }
    }
    String? text;
    Uint8List? image;
    try { text = (await Clipboard.getData(Clipboard.kTextPlain))?.text; } catch (_) {}
    try { image = await Pasteboard.image; } catch (_) {}
    return ClipboardContent(text: text, imagePng: image, mime: image != null ? 'image/png' : null);
  }

  /// Cheap, silent check: is there text on the clipboard? Never triggers the iOS/Android notices.
  Future<bool> hasText() async {
    try { return await Clipboard.hasStrings(); } catch (_) { return false; }
  }

  /// Write an incoming clip locally without triggering our own watcher.
  /// Files are saved to Downloads/Hopper (desktop puts the file on the pasteboard so ⌘V
  /// works in Finder). Returns the saved path for files.
  Future<String?> write(ClipboardContent c) async {
    _suppressUntil = DateTime.now().add(const Duration(milliseconds: 1200));
    try {
      return await _writeInner(c);
    } finally {
      // Our own write bumped the change counter; don't treat it as a user copy.
      final cc = await _macChangeCount();
      if (cc != null) _lastChangeCount = cc;
    }
  }

  Future<String?> _writeInner(ClipboardContent c) async {
    if (c.fileBytes != null) return _writeFile(c);
    if (Platform.isAndroid) {
      if (c.imagePng != null) { await AndroidBridge.write(bytes: c.imagePng, mime: c.mime ?? 'image/png'); return null; }
      if (c.text != null) await AndroidBridge.write(text: c.text);
      return null;
    }
    if (c.imagePng != null) {
      try {
        await Pasteboard.writeImage(c.imagePng!);
        _lastImageLen = c.imagePng!.length;
        return null;
      } catch (_) {
        if (c.text == null) return null;
      }
    }
    if (c.text != null) {
      await Clipboard.setData(ClipboardData(text: c.text!));
      _lastText = c.text;
    }
    return null;
  }

  Future<String?> _writeFile(ClipboardContent c) async {
    final name = _safeName(c.fileName ?? 'hopper-${DateTime.now().millisecondsSinceEpoch}');
    if (Platform.isAndroid) return AndroidBridge.saveFile(c.fileBytes!, name, c.mime);
    final base = isDesktop ? await getDownloadsDirectory() : await getApplicationDocumentsDirectory();
    final dir = Directory('${(base ?? await getApplicationSupportDirectory()).path}${Platform.pathSeparator}Hopper');
    await dir.create(recursive: true);
    var f = File('${dir.path}${Platform.pathSeparator}$name');
    if (await f.exists()) {
      final dot = name.lastIndexOf('.');
      final stem = dot > 0 ? name.substring(0, dot) : name, ext = dot > 0 ? name.substring(dot) : '';
      f = File('${dir.path}${Platform.pathSeparator}$stem-${DateTime.now().millisecondsSinceEpoch}$ext');
    }
    await f.writeAsBytes(c.fileBytes!, flush: true);
    if (isDesktop) {
      try { await Pasteboard.writeFiles([f.path]); _lastFiles = f.path; } catch (_) {}
    }
    return f.path;
  }

  static String _safeName(String n) => n.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();

  static String mimeFor(String name) {
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    return switch (ext) {
      'png' => 'image/png', 'jpg' || 'jpeg' => 'image/jpeg', 'gif' => 'image/gif', 'webp' => 'image/webp', 'heic' => 'image/heic',
      'pdf' => 'application/pdf', 'txt' || 'md' => 'text/plain', 'zip' => 'application/zip',
      'mp4' || 'm4v' => 'video/mp4', 'mov' => 'video/quicktime', 'mp3' => 'audio/mpeg', 'm4a' => 'audio/mp4',
      'doc' => 'application/msword', 'docx' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'xlsx' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'pptx' => 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      'apk' => 'application/vnd.android.package-archive',
      _ => 'application/octet-stream',
    };
  }

  void dispose() { stopWatching(); _changes.close(); }
}

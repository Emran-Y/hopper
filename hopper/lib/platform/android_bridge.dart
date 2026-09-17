
import 'package:flutter/services.dart';

import 'clipboard_service.dart';

/// Dart side of the `hopper/native` channel (see android/.../HopperBridge.kt).
///
/// Android cannot read the clipboard from the background, so the native side owns
/// the always-on foreground service and the capture trick; it pushes captured clips
/// here. Writes also go through native code so they work with no window open.
class AndroidBridge {
  static const _ch = MethodChannel('hopper/native');

  static void init({
    required void Function(ClipboardContent c, bool manual) onCaptured,
    required void Function(String id) onSendHeld,
  }) {
    _ch.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'clipCaptured':
          final m = Map<String, dynamic>.from(call.arguments as Map);
          onCaptured(ClipboardContent.fromNative(m), m['manual'] == true);
        case 'sendHeldClip':
          onSendHeld(call.arguments as String);
      }
    });
  }

  static Future<void> startService() async {
    try { await _ch.invokeMethod('startService'); } catch (_) {}
  }

  static Future<ClipboardContent?> read() async {
    try {
      final m = await _ch.invokeMethod<Map>('readClipboard');
      if (m == null) return null;
      return ClipboardContent.fromNative(Map<String, dynamic>.from(m));
    } catch (_) {
      return null;
    }
  }

  static Future<void> write({String? text, Uint8List? bytes, String? mime}) =>
      _ch.invokeMethod('writeClipboard', {'text': text, 'bytes': bytes, 'mime': mime});

  static Future<String> saveFile(Uint8List bytes, String name, String? mime) async =>
      (await _ch.invokeMethod<String>('saveFile', {'bytes': bytes, 'name': name, 'mime': mime})) ?? name;

  static Future<Map<String, dynamic>> setupStatus() async {
    try {
      final m = await _ch.invokeMethod<Map>('setupStatus');
      return Map<String, dynamic>.from(m ?? {});
    } catch (_) {
      return {};
    }
  }

  static Future<void> startWatcher() => _ch.invokeMethod('startWatcher');
  static Future<void> requestNotifications() => _ch.invokeMethod('requestNotifications');
  static Future<void> requestBattery() => _ch.invokeMethod('requestBattery');
  static Future<void> openOverlaySettings() => _ch.invokeMethod('openOverlaySettings');

  static Future<void> notify({required String title, required String body, String? heldClipId}) async {
    try { await _ch.invokeMethod('notify', {'title': title, 'body': body, 'heldClipId': heldClipId}); } catch (_) {}
  }
}

import 'package:flutter/services.dart';

/// Receives text shared to Hopper via the Android share sheet
/// (see android/app/src/main/kotlin/.../MainActivity.kt).
class ShareIntent {
  static const _ch = MethodChannel('hopper/share');

  static void listen(void Function(String text) onText) {
    _ch.setMethodCallHandler((call) async {
      if (call.method == 'sharedText' && call.arguments is String) onText(call.arguments as String);
    });
    // Ask for anything that arrived before Dart was ready.
    _ch.invokeMethod<String>('getInitialText').then((t) { if (t != null && t.isNotEmpty) onText(t); }).catchError((_) {});
  }
}

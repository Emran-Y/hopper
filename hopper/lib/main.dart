import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/app_controller.dart';
import 'platform/desktop_shell.dart';
import 'platform/share_intent.dart';
import 'ui/onboarding/onboarding_screen.dart';
import 'ui/screens/shell.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final app = AppController();
  await app.init();
  if (DesktopShell.supported) await DesktopShell(app).init();
  if (Platform.isAndroid) ShareIntent.listen((text) => app.sendCurrentClipboard(overrideText: text));
  runApp(ChangeNotifierProvider.value(value: app, child: const HopperApp()));
}

class HopperApp extends StatefulWidget {
  const HopperApp({super.key});
  @override
  State<HopperApp> createState() => _HopperAppState();
}

class _HopperAppState extends State<HopperApp> with WidgetsBindingObserver {
  bool? _onboarded;
  bool _justOnboarded = false;

  @override
  void initState() { super.initState(); WidgetsBinding.instance.addObserver(this); }
  @override
  void dispose() { WidgetsBinding.instance.removeObserver(this); super.dispose(); }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Phones can only read the clipboard while in front: opening Hopper is the send.
    if (state == AppLifecycleState.resumed && (Platform.isAndroid || Platform.isIOS)) {
      context.read<AppController>().syncClipboardOnResume();
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    _onboarded ??= app.settings.onboardingDone;
    return MaterialApp(
      title: 'Hopper',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: switch (app.settings.theme) { 'light' => ThemeMode.light, 'dark' => ThemeMode.dark, _ => ThemeMode.system },
      home: _onboarded!
          ? Shell(showTour: _justOnboarded)
          : OnboardingScreen(onDone: () => setState(() { _onboarded = true; _justOnboarded = true; })),
    );
  }
}

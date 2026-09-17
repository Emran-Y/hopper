# Shipping Hopper for Android

## Sharing with friends (today)

`tool/build.sh android` produces **`dist/Hopper-android.apk`**: one file that installs on any
Android 7+ phone. Send it over any channel (AirDrop won't reach Android; Google Drive, Telegram
"as file", USB all work). On the phone: open the file → allow "install from unknown sources" for that
app once → Install.

The APK is signed with the release key in `~/hopper-release.jks` (password in
`android/key.properties`, never commit that file). **Back both up.** Every future update must be
signed with the same key or phones will refuse to update over the old version.

For automatic sending on their phone, friends need the one-time USB step too
(`tool/android-setup.sh` on a computer with `adb`, or the same three commands over Wireless
debugging). Without it Hopper still receives automatically and sends via Share → Hopper or the
notification's "Send clipboard now".

## Play Store checklist

1. **Google Play Console account** (one-time US$25). Create the app, package `app.hopper.hopper`.
2. **Play App Signing**: on first upload choose "let Google manage the signing key" and upload
   `dist/Hopper-android.aab` (built by `tool/build.sh android`). The key in `key.properties`
   becomes your *upload* key.
3. **Store listing**: name, short/long description, 2–8 phone screenshots (1080×2340 works),
   512×512 icon (`assets/tray/app_icon_1024.png` scaled), feature graphic 1024×500.
4. **Privacy policy URL** (required, even with no data collection). A one-paragraph page:
   Hopper stores clipboard history only on the device, sends it only to devices the user paired,
   end-to-end encrypted, and never to any server.
5. **Data safety form**: no data collected, no data shared, data encrypted in transit, users can
   delete data (clear history / uninstall).
6. **Sensitive permissions to justify in the review notes**:
   - `SYSTEM_ALERT_WINDOW` ("Appear on top") — needed to read the clipboard the instant the user
     copies, because Android only lets a focused window read it.
   - `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` — Play allows it only when core functionality breaks
     without it; explain that the app is a clipboard sync service that must stay connected. If the
     review rejects it, remove the permission and keep the in-app link to the battery settings page.
   - `READ_LOGS` — cannot be granted by the app itself; it is only ever enabled by the user over
     adb. Mention this explicitly; reviewers see it in the manifest.
   - Foreground service type `connectedDevice` — declare it in the console's "Foreground service"
     form: "keeps an encrypted local-network connection to the user's paired devices".
7. **Target API**: 36 (already). **Version**: bump `version:` in `pubspec.yaml` before every upload
   (`0.2.1+3000` → `0.2.2+3001`, the number after `+` must always grow).
8. Upload to **Internal testing** first, add your own Gmail as a tester, install from the Play
   link, then promote to Production.

## What still needs work before a public listing

- Onboarding for phones without adb access (the app should explain the "receive-only" mode well).
- Crash reporting (opt-in) and an "export logs" button.
- Store-quality screenshots and a short demo video.

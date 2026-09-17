# Building Hopper

Hopper is a single Flutter codebase that targets Windows, macOS, Linux, Android and iOS.

**Shortcut on a Mac:** `tool/build.sh android|macos|ios|all` sets up the environment and drops the results in `dist/`. It expects the layout in section 0a and tells you exactly what to install if something is missing (Xcode for macOS/iOS).

## 0. One‑time setup

1. Install **Flutter 3.35 or newer** (stable): <https://docs.flutter.dev/get-started/install>
   Run `flutter doctor` and fix anything it flags for the platforms you want.
2. Platform toolchains:
   - **Windows:** Visual Studio 2022 with the *Desktop development with C++* workload.
   - **macOS:** Xcode 15+ and CocoaPods (`sudo gem install cocoapods`).
   - **Linux (Debian/Ubuntu):** `sudo apt install clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev libstdc++-12-dev libayatana-appindicator3-dev`
   - **Android:** Android Studio (SDK 34+, NDK, command‑line tools) and a JDK 17+. Accept licences with `flutter doctor --android-licenses`.
3. From the project folder:
   ```bash
   flutter pub get
   ```

### 0a. Layout `tool/build.sh` expects on a Mac

| Tool | Where | Installed with |
|---|---|---|
| Flutter 3.35.7 | `~/flutter` | `git clone -b stable https://github.com/flutter/flutter.git ~/flutter && (cd ~/flutter && git checkout 3.35.7)` |
| OpenJDK 17 | `/opt/homebrew/opt/openjdk@17` | `brew install openjdk@17` |
| Android SDK (API 36, build-tools 36, NDK 27) | `/opt/homebrew/share/android-commandlinetools` | `brew install --cask android-commandlinetools` then `sdkmanager --licenses` + `sdkmanager "platform-tools" "platforms;android-36" "build-tools;36.0.0" "ndk;27.0.12077973"` |
| CocoaPods | `/opt/homebrew/bin/pod` | `brew install cocoapods` |
| Xcode (macOS + iOS only) | `/Applications/Xcode.app` | Mac App Store, then `sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer && sudo xcodebuild -license accept` |

Tell Flutter where things are once: `flutter config --jdk-dir=/opt/homebrew/opt/openjdk@17 --android-sdk=/opt/homebrew/share/android-commandlinetools`.

## 1. Run in debug (fastest way to try it)

```bash
flutter devices                    # list what you can run on
flutter run -d windows             # Windows PC
flutter run -d macos               # Mac
flutter run -d linux               # Linux PC
flutter run -d <android-device-id> # phone connected by USB with USB debugging on
```

Run it on the PC and on the phone, then follow the pairing steps in the User Guide.

## 2. Release builds

```bash
# Windows → build/windows/x64/runner/Release/  (zip that whole folder)
flutter build windows --release

# macOS → build/macos/Build/Products/Release/hopper.app
flutter build macos --release

# Linux → build/linux/x64/release/bundle/  (tar that folder)
flutter build linux --release

# Android → build/app/outputs/flutter-apk/app-release.apk
flutter build apk --release
# or per‑ABI (smaller downloads; Samsung and every recent phone is arm64-v8a):
flutter build apk --release --split-per-abi

# iOS → build/ios/iphoneos/Runner.app (needs a signing team selected in Xcode, see below)
flutter build ios --release
```

### iOS signing
Open `ios/Runner.xcworkspace`, select the **Runner** target → *Signing & Capabilities* → tick *Automatically manage signing* and choose your Team. A free Apple ID works for your own iPhone (apps expire after 7 days; rebuild to refresh). Then `flutter run -d <iphone-id> --release` installs it on the plugged‑in phone.

### Signing the Android APK
The debug build is signed with a debug key. For a real release create a keystore once:
```bash
keytool -genkey -v -keystore ~/hopper-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias hopper
```
Then create `android/key.properties`:
```
storePassword=...
keyPassword=...
keyAlias=hopper
storeFile=/absolute/path/to/hopper-release.jks
```
and follow <https://docs.flutter.dev/deployment/android#signing-the-app> to reference it from `android/app/build.gradle.kts`.

### macOS signing / notarisation
Unsigned builds run after right‑click → Open. For distribution outside your own machines, sign with your Developer ID and notarise (`xcrun notarytool`). The project's entitlements already include `com.apple.security.network.client` and `.server`.

## 3. Project layout

```
lib/
  main.dart                     app entry, onboarding vs. main shell
  core/
    app_controller.dart         the sync engine (peers, rules, history, pairing)
    identity.dart               this device's Ed25519 identity
    sensitive_guard.dart        password / OTP / card heuristics
    crypto/crypto_service.dart  X25519, XChaCha20-Poly1305, HKDF, HMAC
    protocol/frames.dart        CBOR frames + length-prefixed framing
    transport/
      lan_transport.dart        TCP listener / dialer
      peer_connection.dart      authenticated handshake + encrypted frames
      discovery.dart            mDNS advertise & browse (_hopper._tcp)
    models/models.dart          Peer, PairRules, Clip, AppSettings
  platform/
    clipboard_service.dart      read/write/watch the OS clipboard
    desktop_shell.dart          tray icon + hide-to-tray
    share_intent.dart           Android share-sheet bridge
  storage/local_store.dart      JSON files under the app data dir
  ui/                           screens, onboarding, tour, widgets
android/app/src/main/kotlin/.../MainActivity.kt   share-sheet receiver
assets/tray/                    tray + app icons
docs/                           this documentation
```

## 4. Common build problems

| Symptom | Fix |
|---|---|
| `CMake Error ... GTK` on Linux | install `libgtk-3-dev` (see step 0) |
| Tray icon missing on Linux | install `libayatana-appindicator3-1` on the target machine |
| `mobile_scanner` fails on Windows/Linux | expected — scanning is mobile/macOS only; those platforms use the 6‑digit code. The package still compiles; nothing to do. |
| Android: `minSdkVersion` error | the app uses Flutter's default (`minSdk = flutter.minSdkVersion`, currently 24 = Android 7.0); raise it in `android/app/build.gradle.kts` if a plugin demands more |
| Firewall prompt on first Windows run | allow on *Private networks* |
| `flutter doctor` complains about Chrome/web | irrelevant; Hopper doesn't target web |

## 5. Tests

```bash
flutter test          # unit tests for framing, crypto round-trip, rules
```

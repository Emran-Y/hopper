#!/usr/bin/env bash
# Build Hopper for one or all platforms from this Mac.
#
#   tool/build.sh android   → dist/Hopper-android.apk (+ .aab for Play)   (Samsung / any Android)
#   tool/build.sh macos     → dist/Hopper.app + dist/Hopper-macos.zip
#   tool/build.sh ios       → build/ios/iphoneos/Runner.app (signed with your Xcode team)
#   tool/build.sh all
#
# Toolchain locations (installed with Homebrew + git clone):
#   Flutter 3.35.7   ~/flutter
#   OpenJDK 17       /opt/homebrew/opt/openjdk@17
#   Android SDK      /opt/homebrew/share/android-commandlinetools
#   CocoaPods        /opt/homebrew/bin/pod
#   Xcode            /Applications/Xcode.app   (App Store — needed for macos/ios)
set -euo pipefail
cd "$(dirname "$0")/.."

export PATH="$HOME/flutter/bin:/opt/homebrew/opt/openjdk@17/bin:/opt/homebrew/bin:$PATH"
export JAVA_HOME=/opt/homebrew/opt/openjdk@17
export ANDROID_HOME=/opt/homebrew/share/android-commandlinetools
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export LANG=en_US.UTF-8   # CocoaPods wants UTF-8
mkdir -p dist

need_xcode() {
  if [ ! -d /Applications/Xcode.app ]; then
    cat <<MSG
✗ Xcode is not installed. macOS and iOS builds need the full Xcode (not just Command Line Tools).
  1. Mac App Store → search "Xcode" → Install (free, ~12 GB).
  2. Open Xcode once, click Agree on the licence and let it install its components.
  3. Re-run: tool/build.sh $1
MSG
    exit 2
  fi
  # Use Xcode directly without needing `sudo xcode-select`.
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
  if ! xcodebuild -version >/dev/null 2>&1; then
    echo "✗ Xcode is installed but its licence is not accepted yet. Open Xcode once and click Agree (or: sudo xcodebuild -license accept)."
    exit 2
  fi
}

build_android() {
  echo "▶ Android (release, signed with android/key.properties if present)"
  flutter build apk --release --split-per-abi
  mkdir -p dist/downloads
  for abi in arm64-v8a armeabi-v7a x86_64; do
    cp "build/app/outputs/flutter-apk/app-$abi-release.apk" "dist/downloads/Hopper-android-$abi.apk"
  done
  cp dist/downloads/Hopper-android-arm64-v8a.apk dist/Hopper-android.apk
  cp tool/android-setup.sh dist/downloads/android-setup.sh
  [ -f dist/Hopper-macos.zip ] && cp dist/Hopper-macos.zip dist/downloads/Hopper-Mac.zip
  echo "✓ dist/Hopper-android.apk (64-bit ARM) + dist/downloads/* for the website"
  echo "▶ Android App Bundle for the Play Store"
  flutter build appbundle --release
  cp build/app/outputs/bundle/release/app-release.aab dist/Hopper-android.aab
  echo "✓ dist/Hopper-android.aab — upload this to Play Console (see docs/PLAYSTORE.md)"
  write_manifest
}

# dist/downloads/manifest.json — what the website's Download section shows (sizes, SHA-256).
write_manifest() {
  VERSION=$(grep -E "^version:" pubspec.yaml | sed 's/version: *//; s/+.*//')
  python3 - "$VERSION" <<'PY'
import hashlib, json, os, sys, datetime
d='dist/downloads'; out=[]
meta={
 'Hopper-Mac.zip':                ('macOS', 'Mac (Apple silicon & Intel)', 'macOS 12 or newer'),
 'Hopper-android-arm64-v8a.apk':  ('Android', 'Android · 64-bit ARM (recommended)', 'Every phone since ~2017, incl. Samsung Galaxy'),
 'Hopper-android-armeabi-v7a.apk':('Android', 'Android · 32-bit ARM', 'Older or budget phones'),
 'Hopper-android-x86_64.apk':     ('Android', 'Android · x86_64', 'Emulators, Chromebooks'),
 'android-setup.sh':              ('Setup', 'Power-user Android setup script (adb)', 'Optional alternative to the Accessibility switch'),
}
for name,(plat,label,note) in meta.items():
    p=os.path.join(d,name)
    if not os.path.exists(p): continue
    b=open(p,'rb').read()
    out.append({'file':name,'platform':plat,'label':label,'note':note,'bytes':len(b),'sha256':hashlib.sha256(b).hexdigest()})
json.dump({'version':sys.argv[1],'built':datetime.date.today().isoformat(),'files':out}, open(os.path.join(d,'manifest.json'),'w'), indent=1)
print('✓ manifest:', ', '.join(o['file'] for o in out))
PY
}

build_macos() {
  need_xcode macos
  echo "▶ macOS (release)"
  flutter build macos --release
  rm -rf dist/Hopper.app
  cp -R build/macos/Build/Products/Release/Hopper.app dist/Hopper.app
  (cd dist && rm -f Hopper-macos.zip && ditto -c -k --keepParent Hopper.app Hopper-macos.zip)
  mkdir -p dist/downloads && cp dist/Hopper-macos.zip dist/downloads/Hopper-Mac.zip && write_manifest
  echo "✓ dist/Hopper.app  (first launch: right-click → Open, it is unsigned)"
}

build_ios() {
  need_xcode ios
  export LANG=en_US.UTF-8
  UDID="${IPHONE_UDID:-$(xcrun devicectl list devices 2>/dev/null | grep -i iphone | grep -vi simulat | grep -oE '[0-9A-F]{8}-[0-9A-F]{16}' | head -1)}"
  echo "▶ iOS (release, signed with the team in ios/Runner.xcodeproj; device: ${UDID:-none})"
  # Make sure Flutter's generated files + pods are current, then let Xcode sign
  # (creates the certificate / profile and registers the phone on first run).
  flutter build ios --release --no-codesign >/dev/null
  DEST=${UDID:+-destination "id=$UDID"}
  xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -configuration Release ${DEST:-"-destination" "generic/platform=iOS"} \
    -allowProvisioningUpdates -allowProvisioningDeviceRegistration -derivedDataPath build/ios/DerivedData build -quiet
  APP=$(find build/ios/DerivedData/Build/Products -maxdepth 2 -name Runner.app -path "*iphoneos*" | head -1)
  rm -rf dist/Hopper-ios.app && cp -R "$APP" dist/Hopper-ios.app
  echo "✓ dist/Hopper-ios.app"
  if [ -n "$UDID" ]; then
    echo "▶ installing on the iPhone ($UDID)"
    xcrun devicectl device install app --device "$UDID" "$APP" >/dev/null && echo "✓ installed" || echo "✗ install failed — is the phone unlocked and trusted?"
    xcrun devicectl device process launch --device "$UDID" app.hopper.hopper >/dev/null 2>&1 \
      || echo "  If it did not open: on the iPhone go to Settings → General → VPN & Device Management → trust the developer app, then tap Hopper."
    echo "  Free Apple IDs: the app stops opening after 7 days; just run  tool/build.sh ios  again."
  else
    echo "  No iPhone connected — plug it in (unlocked, trusted) and re-run to install."
  fi
}

case "${1:-all}" in
  android) build_android ;;
  macos)   build_macos ;;
  ios)     build_ios ;;
  all)     build_android; build_macos; build_ios ;;
  *) echo "usage: tool/build.sh [android|macos|ios|all]"; exit 1 ;;
esac

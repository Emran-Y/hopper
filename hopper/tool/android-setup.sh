#!/usr/bin/env bash
# One-time Android setup for automatic clipboard capture (the KDE Connect method).
#
# Android 10+ refuses clipboard reads from background apps. Two things let Hopper work
# around that, and both can only be switched on by the phone's owner over adb:
#   READ_LOGS            lets Hopper notice the system's "clipboard access denied" log line,
#                        i.e. learn *that* something was copied, the instant it happens.
#   SYSTEM_ALERT_WINDOW  ("Appear on top") lets Hopper raise its invisible capture activity
#                        from the background to read the clip.
# We also exempt Hopper from battery optimisation so One UI keeps it alive.
#
# Usage:  plug the phone in (Developer options → USB debugging on, tap "Allow" on the phone)
#         tool/android-setup.sh
#     or  over Wi-Fi:  adb pair <ip:port>  then  adb connect <ip:port>  then run this script.
set -euo pipefail
PKG=app.hopper.hopper
export PATH="/opt/homebrew/bin:/opt/homebrew/share/android-commandlinetools/platform-tools:$PATH"

if ! command -v adb >/dev/null; then
  echo "adb not found. Install: brew install --cask android-platform-tools"; exit 1
fi

devices=$(adb devices | awk 'NR>1 && $2=="device" {print $1}')
if [ -z "$devices" ]; then
  echo "No phone found. Plug it in, enable USB debugging (Settings → Developer options), and tap Allow on the phone."
  adb devices
  exit 1
fi
if [ "$(echo "$devices" | wc -l | tr -d ' ')" != "1" ]; then
  echo "More than one device connected; set ANDROID_SERIAL=<id> and re-run."; adb devices; exit 1
fi

if ! adb shell pm list packages | grep -q "^package:$PKG$"; then
  apk="$(dirname "$0")/../dist/hopper-arm64-v8a-release.apk"
  echo "Hopper is not installed on the phone; installing $apk"
  adb install -r "$apk"
fi

echo "▶ granting READ_LOGS (automatic capture)"
adb shell pm grant "$PKG" android.permission.READ_LOGS
echo "▶ allowing 'Appear on top'"
adb shell appops set "$PKG" SYSTEM_ALERT_WINDOW allow
echo "▶ exempting from battery optimisation"
adb shell dumpsys deviceidle whitelist "+$PKG" >/dev/null || true
echo "▶ restarting Hopper so the new permissions apply"
adb shell am force-stop "$PKG"
sleep 1
adb shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1 || true

echo
echo "✓ Done. Status on the phone:"
adb shell dumpsys package "$PKG" | grep -E "READ_LOGS|SYSTEM_ALERT_WINDOW" | head -4 || true
echo
echo "Now copy something on the phone — it should appear on your Mac within a second."
echo "If Samsung shows an 'Appear on top' switch in Settings → Apps → Hopper, make sure it is on."

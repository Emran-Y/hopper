import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  // Hopper lives in the menu bar; closing the window hides it (see DesktopShell).
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}

import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    // hopper/mac: cheap pasteboard change detection. macOS has no clipboard change
    // notification, but NSPasteboard.changeCount increments on every write, so Dart polls
    // this number instead of re-reading (and re-encoding) the clipboard contents.
    let channel = FlutterMethodChannel(name: "hopper/mac", binaryMessenger: flutterViewController.engine.binaryMessenger)
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "changeCount":
        result(NSPasteboard.general.changeCount)
      case "types":
        result(NSPasteboard.general.types?.map { $0.rawValue } ?? [])
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    super.awakeFromNib()
  }
}

import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    ClipboardImageChannel.register(
      messenger: flutterViewController.engine.binaryMessenger)

    super.awakeFromNib()
  }
}

/// Images on the pasteboard for Wonky Sheets (`wonky.sheets/clipboard`,
/// Sheets 08 §9.5, §10.1): `readImage` returns `{png, hasText}` (PNG or TIFF
/// data converted to PNG); `writeImage` puts `{png, text?}` on the pasteboard.
enum ClipboardImageChannel {
  static func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "wonky.sheets/clipboard", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      let board = NSPasteboard.general
      switch call.method {
      case "readImage":
        let text = board.string(forType: .string) ?? ""
        let hasText = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if let png = board.data(forType: .png) {
          result(["png": FlutterStandardTypedData(bytes: png), "hasText": hasText])
          return
        }
        if let tiff = board.data(forType: .tiff),
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:])
        {
          result(["png": FlutterStandardTypedData(bytes: png), "hasText": hasText])
          return
        }
        result(nil)
      case "writeImage":
        guard let args = call.arguments as? [String: Any],
          let data = args["png"] as? FlutterStandardTypedData
        else {
          result(false)
          return
        }
        board.clearContents()
        board.setData(data.data, forType: .png)
        if let text = args["text"] as? String {
          board.setString(text, forType: .string)
        }
        result(true)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}

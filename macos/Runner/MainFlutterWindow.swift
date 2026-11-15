import Cocoa
import FlutterMacOS
import desktop_multi_window

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    FlutterMultiWindowPlugin.setOnWindowCreatedCallback { controller in
      // The mini window's engine renders state and forwards commands; it never
      // touches audio. Registering everything here a second time (audio_service,
      // media_kit, music_kit) initializes their native singletons twice in one
      // process, which corrupts the Dart heap. Register the plugins the guest
      // actually reads.
      FlutterMultiWindowPlugin.register(with: controller.registrar(forPlugin: "FlutterMultiWindowPlugin"))
    }
    super.awakeFromNib()
  }
}

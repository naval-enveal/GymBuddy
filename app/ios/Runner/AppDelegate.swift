import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var glassesChannel: GlassesChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // The glasses platform channel (DAT SDK: camera/audio/mic). Safe to wire up
    // with no hardware — it reports `unavailable` and the Dart layer falls back
    // to MockSensorSource. A dedicated registrar gives us the binary messenger.
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "GymBuddyGlasses") {
      glassesChannel = GlassesChannel(messenger: registrar.messenger())
    }
  }

  override func applicationWillTerminate(_ application: UIApplication) {
    glassesChannel?.dispose()
    glassesChannel = nil
    super.applicationWillTerminate(application)
  }
}

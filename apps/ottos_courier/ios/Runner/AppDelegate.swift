import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "OttosStorage") {
      OttosStorage.register(messenger: registrar.messenger())
    }
  }
}

/// Answers `ottos/storage`: the folder for the offline database, out of
/// iCloud and computer backups (SEC-2), in Library/Application Support.
enum OttosStorage {
  static func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "ottos/storage", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "offlineDirectory" else {
        result(FlutterMethodNotImplemented)
        return
      }
      do {
        result(try offlineDirectory().path)
      } catch {
        result(FlutterError(code: "STORAGE", message: error.localizedDescription, details: nil))
      }
    }
  }

  static func offlineDirectory() throws -> URL {
    let support = try FileManager.default.url(
      for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
    var folder = support.appendingPathComponent("offline", isDirectory: true)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    var values = URLResourceValues()
    values.isExcludedFromBackup = true
    try folder.setResourceValues(values)
    return folder
  }
}

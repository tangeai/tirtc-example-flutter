import AVFoundation
import Flutter
import Network
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let preferencesChannelName = "tirtc_av_kit_example/preferences"
  private let preferencesKeyPrefix = "tirtc_av_kit_example."
  private var localNetworkBrowser: NWBrowser?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "tirtc_av_kit_example/permissions",
        binaryMessenger: controller.binaryMessenger
      )
      channel.setMethodCallHandler { [weak self] call, result in
        guard let self else {
          result(FlutterError(
            code: "UNAVAILABLE",
            message: "permissions channel owner unavailable",
            details: nil
          ))
          return
        }
        switch call.method {
        case "checkLocalMediaPermissions":
          result(self.localMediaPermissionsGranted())
        case "requestLocalMediaPermissions":
          self.requestLocalMediaPermissions(result: result)
        case "requestLocalNetworkPermission":
          self.requestLocalNetworkPermission(result: result)
        default:
          result(FlutterMethodNotImplemented)
        }
      }

      let preferencesChannel = FlutterMethodChannel(
        name: preferencesChannelName,
        binaryMessenger: controller.binaryMessenger
      )
      preferencesChannel.setMethodCallHandler { [weak self] call, result in
        guard let self else {
          result(FlutterError(
            code: "UNAVAILABLE",
            message: "preferences channel owner unavailable",
            details: nil
          ))
          return
        }
        self.handlePreferencesCall(call, result: result)
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func handlePreferencesCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "putPreferencesInt":
      guard let (key, value) = intWriteArguments(call.arguments, valueKey: "value", result: result) else {
        return
      }
      UserDefaults.standard.set(value, forKey: key)
      result(nil)
    case "getPreferencesInt":
      guard let (key, defaultValue) = intWriteArguments(
        call.arguments,
        valueKey: "defaultValue",
        result: result
      ) else {
        return
      }
      if UserDefaults.standard.object(forKey: key) == nil {
        result(defaultValue)
        return
      }
      result(UserDefaults.standard.integer(forKey: key))
    case "putPreferencesString":
      guard let (key, value) = stringWriteArguments(call.arguments, valueKey: "value", result: result) else {
        return
      }
      UserDefaults.standard.set(value, forKey: key)
      result(nil)
    case "getPreferencesString":
      guard let (key, defaultValue) = stringWriteArguments(
        call.arguments,
        valueKey: "defaultValue",
        result: result
      ) else {
        return
      }
      result(UserDefaults.standard.string(forKey: key) ?? defaultValue)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func intWriteArguments(
    _ rawArguments: Any?,
    valueKey: String,
    result: FlutterResult
  ) -> (String, Int)? {
    guard let arguments = rawArguments as? [String: Any],
          let key = arguments["key"] as? String,
          key.hasPrefix(preferencesKeyPrefix),
          let value = arguments[valueKey] as? Int else {
      result(FlutterError(
        code: "INVALID_ARGUMENT",
        message: "key and \(valueKey) are required",
        details: nil
      ))
      return nil
    }
    return (key, value)
  }

  private func stringWriteArguments(
    _ rawArguments: Any?,
    valueKey: String,
    result: FlutterResult
  ) -> (String, String)? {
    guard let arguments = rawArguments as? [String: Any],
          let key = arguments["key"] as? String,
          key.hasPrefix(preferencesKeyPrefix),
          let value = arguments[valueKey] as? String else {
      result(FlutterError(
        code: "INVALID_ARGUMENT",
        message: "key and \(valueKey) are required",
        details: nil
      ))
      return nil
    }
    return (key, value)
  }

  private func requestLocalNetworkPermission(result: @escaping FlutterResult) {
    if localNetworkBrowser != nil {
      result(true)
      return
    }

    let parameters = NWParameters.tcp
    let browser = NWBrowser(
      for: .bonjour(type: "_tirtc-demo._tcp", domain: nil),
      using: parameters
    )
    browser.stateUpdateHandler = { state in
      switch state {
      case .failed(let error):
        NSLog("[TiRTCLab] local network browser failed: %@", String(describing: error))
      default:
        break
      }
    }
    browser.browseResultsChangedHandler = { _, _ in }
    localNetworkBrowser = browser
    browser.start(queue: .main)

    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
      self?.localNetworkBrowser?.cancel()
      self?.localNetworkBrowser = nil
    }
    result(true)
  }

  private func localMediaPermissionsGranted() -> Bool {
    AVCaptureDevice.authorizationStatus(for: .video) == .authorized &&
      AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
  }

  private func requestLocalMediaPermissions(result: @escaping FlutterResult) {
    requestCaptureAccessIfNeeded(for: .video) { videoGranted in
      guard videoGranted else {
        result(false)
        return
      }
      self.requestCaptureAccessIfNeeded(for: .audio) { audioGranted in
        result(audioGranted)
      }
    }
  }

  private func requestCaptureAccessIfNeeded(
    for mediaType: AVMediaType,
    completion: @escaping (Bool) -> Void
  ) {
    switch AVCaptureDevice.authorizationStatus(for: mediaType) {
    case .authorized:
      completion(true)
    case .notDetermined:
      AVCaptureDevice.requestAccess(for: mediaType) { granted in
        DispatchQueue.main.async {
          completion(granted)
        }
      }
    case .denied, .restricted:
      completion(false)
    @unknown default:
      completion(false)
    }
  }
}

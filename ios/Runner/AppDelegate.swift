import Flutter
import Network
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
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
        guard call.method == "requestLocalNetworkPermission" else {
          result(FlutterMethodNotImplemented)
          return
        }
        self?.requestLocalNetworkPermission(result: result)
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
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
}

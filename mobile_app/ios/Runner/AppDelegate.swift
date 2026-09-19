import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let paymentReturnChannelName = "kz.boombala/payment_return"
  private var paymentReturnChannel: FlutterMethodChannel?
  private var initialPaymentLink: String?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(
      name: paymentReturnChannelName,
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    paymentReturnChannel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "getInitialLink" else {
        result(FlutterMethodNotImplemented)
        return
      }
      result(self?.initialPaymentLink)
      self?.initialPaymentLink = nil
    }
  }

  func handlePaymentURL(_ url: URL) {
    let link = url.absoluteString
    initialPaymentLink = link
    paymentReturnChannel?.invokeMethod("paymentLink", arguments: link)
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    handlePaymentURL(url)
    return super.application(app, open: url, options: options)
  }
}

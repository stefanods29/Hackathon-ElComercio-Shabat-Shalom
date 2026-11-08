import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var sensitiveScreen = false
  private var privacyCover: UIVisualEffectView?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(concealSensitiveScreen(_:)),
      name: UIScene.willDeactivateNotification,
      object: nil
    )
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(
      name: "pe.shabatshalom.vecinal/pantalla_sensible",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(FlutterError(code: "unavailable", message: nil, details: nil))
        return
      }
      switch call.method {
      case "setEnabled":
        guard let enabled = call.arguments as? Bool else {
          result(FlutterError(code: "invalid_arguments", message: nil, details: nil))
          return
        }
        self.sensitiveScreen = enabled
        if !enabled { self.removeCover() }
        result(nil)
      case "foregroundReady":
        // Flutter has drawn a safe frame. Until then the previous frame stays obscured.
        if self.privacyCover?.window?.windowScene?.activationState == .foregroundActive {
          self.removeCover()
        }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  @objc private func concealSensitiveScreen(_ notification: Notification) {
    guard sensitiveScreen,
      let scene = notification.object as? UIWindowScene,
      let window = (scene.delegate as? FlutterSceneDelegate)?.window
        ?? scene.windows.first(where: { $0.isKeyWindow })
    else { return }

    removeCover()
    let cover = UIVisualEffectView(effect: UIBlurEffect(style: .systemThickMaterial))
    cover.frame = window.bounds
    cover.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    cover.contentView.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.96)
    cover.accessibilityElementsHidden = true
    window.addSubview(cover)
    privacyCover = cover
  }

  private func removeCover() {
    privacyCover?.removeFromSuperview()
    privacyCover = nil
  }
}

import ContactsUI
import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var sensitiveScreen = false
  private var privacyCover: UIVisualEffectView?
  /// The contact picker in progress: its delegate must stay alive until it answers.
  private var contactPicker: ContactPickerDelegate?

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

    let messenger = engineBridge.applicationRegistrar.messenger()
    // The phone's own contact picker: Winki only receives the contact the neighbor taps.
    FlutterMethodChannel(name: "pe.shabatshalom.vecinal/agenda", binaryMessenger: messenger)
      .setMethodCallHandler { [weak self] call, result in
        guard call.method == "pickContact" else {
          result(FlutterMethodNotImplemented)
          return
        }
        guard let self = self else {
          result(FlutterError(code: "unavailable", message: nil, details: nil))
          return
        }
        self.pickContact(result)
      }
    // A notification made on the phone itself, for the practice simulation of an urgent notice.
    FlutterMethodChannel(name: "pe.shabatshalom.vecinal/avisos_locales", binaryMessenger: messenger)
      .setMethodCallHandler { call, result in
        guard call.method == "show" else {
          result(FlutterMethodNotImplemented)
          return
        }
        guard let arguments = call.arguments as? [String: Any],
          let title = arguments["title"] as? String,
          let body = arguments["body"] as? String
        else {
          result(FlutterError(code: "invalid_arguments", message: nil, details: nil))
          return
        }
        let delay = Double(arguments["delayMs"] as? Int ?? 0) / 1000
        AppDelegate.scheduleNotification(title: title, body: body, delay: delay, result: result)
      }
  }

  private func pickContact(_ result: @escaping FlutterResult) {
    guard contactPicker == nil else {
      result(FlutterError(code: "busy", message: nil, details: nil))
      return
    }
    guard let presenter = topViewController() else {
      result(FlutterError(code: "unavailable", message: nil, details: nil))
      return
    }
    let picker = CNContactPickerViewController()
    picker.displayedPropertyKeys = [CNContactPhoneNumbersKey]
    picker.predicateForEnablingContact = NSPredicate(format: "phoneNumbers.@count > 0")
    // With one number the contact is chosen at once; with several, the neighbor taps the number.
    picker.predicateForSelectionOfContact = NSPredicate(format: "phoneNumbers.@count == 1")
    let delegate = ContactPickerDelegate { [weak self] value in
      result(value)
      self?.contactPicker = nil
    }
    picker.delegate = delegate
    contactPicker = delegate
    presenter.present(picker, animated: true)
  }

  private func topViewController() -> UIViewController? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let windows = scenes.flatMap { $0.windows }
    var top = (windows.first { $0.isKeyWindow } ?? windows.first)?.rootViewController
    while let presented = top?.presentedViewController { top = presented }
    return top
  }

  /// iOS does not show a notification over the app in use, so it arrives after a short delay.
  private static func scheduleNotification(
    title: String, body: String, delay: Double, result: @escaping FlutterResult
  ) {
    let center = UNUserNotificationCenter.current()
    center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
      guard granted else {
        DispatchQueue.main.async { result("denied") }
        return
      }
      let content = UNMutableNotificationContent()
      content.title = title
      content.body = body
      content.sound = .default
      let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, delay), repeats: false)
      let request = UNNotificationRequest(
        identifier: "winki-simulado-\(UUID().uuidString)", content: content, trigger: trigger)
      center.add(request) { error in
        DispatchQueue.main.async { result(error == nil ? "scheduled" : "failed") }
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

/// Answers the contact picker once: the name and the numbers of the chosen contact, or nil.
final class ContactPickerDelegate: NSObject, CNContactPickerDelegate {
  private var complete: (([String: Any]?) -> Void)?

  init(complete: @escaping ([String: Any]?) -> Void) {
    self.complete = complete
  }

  private func finish(_ value: [String: Any]?) {
    complete?(value)
    complete = nil
  }

  func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
    finish(nil)
  }

  func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
    finish(["name": Self.name(of: contact), "phones": Self.phones(of: contact)])
  }

  func contactPicker(
    _ picker: CNContactPickerViewController, didSelect contactProperty: CNContactProperty
  ) {
    let chosen = (contactProperty.value as? CNPhoneNumber)?.stringValue
    let others = Self.phones(of: contactProperty.contact).filter { $0 != chosen }
    finish([
      "name": Self.name(of: contactProperty.contact),
      "phones": (chosen.map { [$0] } ?? []) + others,
    ])
  }

  private static func name(of contact: CNContact) -> String {
    var parts: [String] = []
    if contact.isKeyAvailable(CNContactGivenNameKey) { parts.append(contact.givenName) }
    if contact.isKeyAvailable(CNContactFamilyNameKey) { parts.append(contact.familyName) }
    let joined = parts.filter { !$0.isEmpty }.joined(separator: " ")
    if !joined.isEmpty { return joined }
    if contact.isKeyAvailable(CNContactOrganizationNameKey) { return contact.organizationName }
    return ""
  }

  private static func phones(of contact: CNContact) -> [String] {
    guard contact.isKeyAvailable(CNContactPhoneNumbersKey) else { return [] }
    return contact.phoneNumbers.map { $0.value.stringValue }
  }
}

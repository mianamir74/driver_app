import Flutter
import UIKit
import FirebaseAuth

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // TEMPORARY DIAGNOSTIC: wipe Keychain on EVERY launch (not gated to once).
    // The one-time version wasn't enough — signing in during testing writes a
    // brand-new session to Keychain, and THAT session hits the same crash on
    // the next cold launch, re-trapping the test device. Wiping every launch
    // keeps the device testable while we chase the real fix. This must be
    // reverted to one-time (or removed) before shipping to real users —
    // it currently signs everyone out on every app open.
    Self.wipeKeychainEveryLaunch()

    GeneratedPluginRegistrant.register(with: self)
    // Register for remote notifications so Firebase Phone Auth can use APNs
    application.registerForRemoteNotifications()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private static func wipeKeychainEveryLaunch() {
    let secClasses: [CFString] = [
      kSecClassGenericPassword,
      kSecClassInternetPassword,
      kSecClassCertificate,
      kSecClassKey,
      kSecClassIdentity,
    ]
    for secClass in secClasses {
      let query: [CFString: Any] = [kSecClass: secClass]
      SecItemDelete(query as CFDictionary)
    }
  }

  // Forward APNs device token to Firebase Auth
  // RESTORED to exact build-503 (ba4d859, last confirmed-working) form — the
  // DispatchQueue.main.async wrapper and the .prod override added afterward
  // were never actually validated against a working build (the crash never
  // stopped after either was added), so they're being pulled back out to get
  // a clean before/after test.
  override func application(_ application: UIApplication,
                             didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    Auth.auth().setAPNSToken(deviceToken, type: .unknown)
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  // Forward silent push notifications to Firebase Auth (for phone verification)
  override func application(_ application: UIApplication,
                             didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                             fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
    if Auth.auth().canHandleNotification(userInfo) {
      completionHandler(.noData)
      return
    }
    super.application(application, didReceiveRemoteNotification: userInfo,
                      fetchCompletionHandler: completionHandler)
  }

  // Forward URL callbacks to Firebase Auth (for reCAPTCHA fallback)
  override func application(_ application: UIApplication,
                             open url: URL,
                             options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
    if Auth.auth().canHandle(url) { return true }
    return super.application(application, open: url, options: options)
  }
}

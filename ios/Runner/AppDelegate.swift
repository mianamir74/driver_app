import Flutter
import UIKit
import FirebaseAuth

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // One-time Keychain wipe for this app — runs before Firebase/Flutter touch
    // anything. This device has been used for many rounds of phone-auth crash
    // testing; iOS Keychain data is NOT cleared by deleting the app (already
    // tried) or by Reset Network Settings (also tried) — it only goes away on
    // a full "Erase All Content and Settings" or if something explicitly
    // deletes it. This does the deletion in code instead, exactly once per
    // install (guarded by a UserDefaults flag so normal users don't get
    // logged out on every launch going forward).
    Self.wipeKeychainOnce()

    GeneratedPluginRegistrant.register(with: self)
    // Register for remote notifications so Firebase Phone Auth can use APNs
    application.registerForRemoteNotifications()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private static func wipeKeychainOnce() {
    let flagKey = "goouts_keychain_wiped_v1"
    guard !UserDefaults.standard.bool(forKey: flagKey) else { return }

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

    UserDefaults.standard.set(true, forKey: flagKey)
    UserDefaults.standard.synchronize()
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

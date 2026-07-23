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

  // Forward APNs device token to Firebase Auth.
  // Switching to .prod (was .unknown, matching build 503). We've now confirmed
  // build 503's exact code still fails at signInWithCredential with the
  // Keychain issue removed as a variable (every-launch wipe, build 516) — so
  // .unknown was never actually a "working" setting for THIS specific call,
  // it just never got exercised far enough to prove it out before. Every
  // build we ship is TestFlight/App Store, always production APNs — .prod
  // removes Firebase's environment auto-detection from the equation entirely.
  override func application(_ application: UIApplication,
                             didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    Auth.auth().setAPNSToken(deviceToken, type: .prod)
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

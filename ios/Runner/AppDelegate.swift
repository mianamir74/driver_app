import Flutter
import UIKit
import FirebaseAuth

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    // Register for remote notifications so Firebase Phone Auth can use APNs
    application.registerForRemoteNotifications()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Forward APNs device token to Firebase Auth.
  // Deferred to the next run loop tick via DispatchQueue.main.async — calling
  // Auth.auth().setAPNSToken() synchronously inside this delegate callback can
  // fire before the app's UIWindowScene is fully attached (this callback can
  // arrive extremely early on cold launch, before Flutter's engine/window is
  // ready), which crashes Firebase Auth's iOS SDK with a Swift precondition
  // failure. Pushing it to the next tick lets scene attachment finish first.
  //
  // type: .prod (not .unknown) — every build we ship goes out via TestFlight/
  // App Store, which always runs in the production APNs environment. .unknown
  // asks Firebase to auto-detect the environment by parsing the embedded
  // provisioning profile, and that detection is known to misfire on IPAs
  // built by non-Xcode CI pipelines (like `flutter build ipa` on GitHub
  // Actions). If Firebase silently records the token under the wrong
  // environment, the silent push it sends during phone-auth verification
  // (verifyClient) never reaches this device, and the SDK's internal wait/
  // retry loop for that push can spin — a plausible explanation for the
  // memory blow-up (Jetsam per-process-limit) seen on launch. Being explicit
  // removes that guesswork entirely.
  override func application(_ application: UIApplication,
                             didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    DispatchQueue.main.async {
      Auth.auth().setAPNSToken(deviceToken, type: .prod)
    }
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

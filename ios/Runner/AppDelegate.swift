import Flutter
import UIKit
import FirebaseAuth

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // REMOVED (build 527): build 526's native crash handler (SIGABRT/SIGSEGV/
    // etc. + NSSetUncaughtExceptionHandler) confirmed conclusively that no
    // catchable exception/signal ever fires — last_native_crash.log never
    // appeared across repeated crashes, while JetsamEvent reports kept
    // appearing. That's the answer it was built to get: this was a genuine
    // uncatchable kernel SIGKILL, not a hidden catchable bug. Removed now
    // that we have a real fix for the actual cause (concurrent
    // signInWithCredential race, see services/auth_service.dart).

    // REMOVED (see lib/features/auth/services/auth_service.dart): the
    // every-launch Keychain wipe was a temporary diagnostic to keep test
    // devices usable while chasing the OTP-Continue crash. The real cause
    // (a late silent-push auto-verification racing the user's manual
    // signInWithCredential call) is now fixed at the source — the auto
    // credential is dropped instead of raced. Wiping Keychain on every
    // launch signed every user out on every app open, which was never
    // acceptable for real users; safe to remove now the actual bug is fixed.

    GeneratedPluginRegistrant.register(with: self)
    // Register for remote notifications so Firebase Phone Auth can use APNs
    application.registerForRemoteNotifications()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
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

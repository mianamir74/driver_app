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
    application.registerForRemoteNotifications()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(_ application: UIApplication,
                             didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    // DO NOT call Auth.auth().setAPNSToken() here.
    // The Firebase Auth delegate proxy (FirebaseAppDelegateProxyEnabled = YES by default)
    // intercepts this callback and stores the token internally.
    // Calling setAPNSToken() manually at startup causes a preconditionFailure crash
    // because there is no pending phone-verification callback yet.
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  override func application(_ application: UIApplication,
                             didFailToRegisterForRemoteNotificationsWithError error: Error) {
    // Log APNs registration failure — visible in Crashlytics non-fatal events.
    // If this fires, Firebase Phone Auth will always fall back to reCAPTCHA.
    print("⚠️ APNs registration FAILED: \(error.localizedDescription)")
    super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
  }

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

  override func application(_ application: UIApplication,
                             open url: URL,
                             options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
    if Auth.auth().canHandle(url) { return true }
    return super.application(application, open: url, options: options)
  }
}

import Flutter
import UIKit
import FirebaseAuth

// MARK: - TEMP DIAGNOSTIC (build 526) — native crash capture, remove once we
// have captured one report.
//
// Zero new reports have appeared in iOS's own Analytics Data after the last
// clean-device OTP-Continue crash test — either "Share iPhone Analytics" is
// off, or something is preventing the OS's own crash reporter from writing
// one. This writes an independent log directly into the app's own Documents
// folder, retrievable via the iPhone's Files app (On My iPhone > GoOuts Lead)
// with NO dependency on Analytics Data, Crashlytics, or a Mac.
//
// IMPORTANT CAVEAT, so we read the result correctly either way: this can
// only catch a genuine exception/signal (SIGABRT, SIGSEGV, SIGILL, SIGFPE,
// SIGBUS, SIGTRAP). A kernel Jetsam OOM kill is delivered as SIGKILL, which
// by POSIX design cannot be caught by ANY handler in ANY app — that's an OS
// guarantee, not a gap in this code. So:
//   - If last_native_crash.log appears after the next crash -> this was
//     NEVER a Jetsam OOM kill, it's a real catchable exception, and we get
//     an actual (if unsymbolicated) stack trace to work from.
//   - If it does NOT appear -> either it's truly an uncatchable SIGKILL, or
//     something is killing the app before this code even runs.
private func gooutsCrashLogPath() -> URL? {
  guard let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
    return nil
  }
  return dir.appendingPathComponent("last_native_crash.log")
}

private func gooutsWriteCrashLog(_ text: String) {
  guard let path = gooutsCrashLogPath() else { return }
  let stamped = "[\(Date())]\n\(text)\n"
  try? stamped.write(to: path, atomically: true, encoding: .utf8)
}

private func gooutsUncaughtExceptionHandler(_ exception: NSException) {
  let text = """
  UNCAUGHT NSEXCEPTION
  name: \(exception.name.rawValue)
  reason: \(exception.reason ?? "nil")
  userInfo: \(String(describing: exception.userInfo))
  callStackSymbols:
  \(exception.callStackSymbols.joined(separator: "\n"))
  """
  gooutsWriteCrashLog(text)
}

private func gooutsSignalHandler(_ sig: Int32) {
  let text = """
  UNCAUGHT SIGNAL
  signal: \(sig)
  callStackSymbols:
  \(Thread.callStackSymbols.joined(separator: "\n"))
  """
  gooutsWriteCrashLog(text)
  signal(sig, SIG_DFL)
  raise(sig)
}

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // TEMP DIAGNOSTIC (build 526): install native crash capture FIRST, before
    // anything else has a chance to crash. See comment block above.
    NSSetUncaughtExceptionHandler(gooutsUncaughtExceptionHandler)
    signal(SIGABRT, gooutsSignalHandler)
    signal(SIGILL, gooutsSignalHandler)
    signal(SIGSEGV, gooutsSignalHandler)
    signal(SIGFPE, gooutsSignalHandler)
    signal(SIGBUS, gooutsSignalHandler)
    signal(SIGTRAP, gooutsSignalHandler)

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

  // NARROWED (build 524): FirebaseAuth persists its session using ONLY
  // kSecClassGenericPassword (FIRAuthKeychainServices) — that's the only
  // class that ever needs wiping to clear a stale/corrupted Auth session.
  // The previous version also wiped kSecClassCertificate, kSecClassKey and
  // kSecClassIdentity EVERY launch. Those hold cryptographic keys/certs
  // that iOS's own TLS/Secure Enclave layer can create and rely on — and
  // signInWithCredential's native networking code has to do a fresh HTTPS
  // handshake with Google's servers right after this wipe runs. Nuking key
  // material every single launch is unusually aggressive and is a
  // plausible contributor to the CPU-heavy, memory-ballooning OOM kill
  // that consistently happens the moment signInWithCredential is called.
  // Narrowing the wipe removes that as a variable without giving up the
  // original fix (clearing a stale Auth session).
  private static func wipeKeychainEveryLaunch() {
    let secClasses: [CFString] = [
      kSecClassGenericPassword,
      kSecClassInternetPassword,
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

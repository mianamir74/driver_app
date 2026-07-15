import Flutter
import UIKit
import FirebaseAuth

class SceneDelegate: FlutterSceneDelegate {

  // Required for Firebase Phone Auth reCAPTCHA fallback.
  // In iOS 13+ scene-based apps, URL callbacks go here, not AppDelegate.
  override func scene(_ scene: UIScene,
                      openURLContexts URLContexts: Set<UIOpenURLContext>) {
    for context in URLContexts {
      if Auth.auth().canHandle(context.url) {
        return
      }
    }
    super.scene(scene, openURLContexts: URLContexts)
  }
}

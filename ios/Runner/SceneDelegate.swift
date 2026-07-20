import Flutter
import UIKit
import FirebaseAuth

class SceneDelegate: FlutterSceneDelegate {
  // Forward URL callbacks to Firebase Auth (for reCAPTCHA phone auth fallback)
  override func scene(_ scene: UIScene,
                      openURLContexts URLContexts: Set<UIOpenURLContext>) {
    for context in URLContexts {
      if Auth.auth().canHandle(context.url) { return }
    }
    super.scene(scene, openURLContexts: URLContexts)
  }
}

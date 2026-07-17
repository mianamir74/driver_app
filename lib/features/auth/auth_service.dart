import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> sendOtp({
    required String phoneNumber,
    required void Function(String verificationId) onCodeSent,
    required void Function() onAutoVerified,
    required void Function(String message) onError,
  }) async {
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        // timeout: Duration.zero forces Firebase Auth to skip the APNs silent-push
        // path entirely on iOS and go straight to reCAPTCHA. Without this, Firebase
        // waits the default 30 seconds for an APNs push that can never arrive
        // (no APNs key is configured in Firebase Console for this app), and then
        // crashes in Swift async Task cleanup (EXC_BREAKPOINT / SIGTRAP — builds 11-15).
        timeout: Duration.zero,
        verificationCompleted: (PhoneAuthCredential credential) async {
          try {
            await _auth.signInWithCredential(credential);
            onAutoVerified();
          } catch (e) {
            onError('Auto-verification failed. Please enter the code manually.');
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          onError(e.message ?? 'Failed to send OTP.');
        },
        codeSent: (String verificationId, int? resendToken) {
          onCodeSent(verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {},
      );
    } catch (e) {
      onError('Could not send verification code. Please check your connection and try again.');
    }
  }

  Future<void> verifyOtp({
    required String verificationId,
    required String smsCode,
  }) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );

    await _auth.signInWithCredential(credential);
  }
}

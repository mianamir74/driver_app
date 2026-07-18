import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Send OTP to a phone number in E.164 format (e.g. +447911123456).
  /// Mirrors the working pattern used in the GoOuts consumer app.
  Future<void> sendOtp({
    required String phoneNumber,
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function() onAutoVerified,
    required void Function(String message) onError,
  }) async {
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          try {
            await _auth.signInWithCredential(credential);
            onAutoVerified();
          } catch (e) {
            onError('Auto-verification failed. Please enter the code manually.');
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          onError(e.message ?? 'Failed to send OTP. Please try again.');
        },
        codeSent: (String verificationId, int? resendToken) {
          onCodeSent(verificationId, resendToken);
        },
        codeAutoRetrievalTimeout: (String verificationId) {},
      );
    } catch (e) {
      onError(
        'Could not send verification code. '
        'Please check your connection and try again.',
      );
    }
  }

  /// Resend OTP using the resend token.
  Future<void> resendOtp({
    required String phoneNumber,
    required int? resendToken,
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function(String message) onError,
  }) async {
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        forceResendingToken: resendToken,
        verificationCompleted: (_) {},
        verificationFailed: (FirebaseAuthException e) {
          onError(e.message ?? 'Failed to resend OTP.');
        },
        codeSent: (String verificationId, int? newResendToken) {
          onCodeSent(verificationId, newResendToken);
        },
        codeAutoRetrievalTimeout: (_) {},
      );
    } catch (e) {
      onError('Could not resend code. Please check your connection and try again.');
    }
  }

  User? get currentUser => _auth.currentUser;
  Future<void> signOut() => _auth.signOut();
  Stream<User?> get authStateChanges => _auth.authStateChanges();
}

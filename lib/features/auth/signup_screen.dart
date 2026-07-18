// Temporary phone-auth test screen — mirrors the working GoOuts consumer-app
// signup_screen.dart pattern exactly. Use this to verify the AuthService
// sendOtp() call works on iOS before restoring the full LoginScreen UI.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'services/auth_service.dart';
import 'otp_verification_screen.dart';
import 'widgets/pre_auth_support_sheet.dart';
import 'package:driver_app/features/common/goouts_sheet.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _phoneController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;

  static const Color _primary = Color(0xFF0392CA);

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    final number = _phoneController.text.trim();
    if (number.length < 10) {
      GoOutsSheet.warning(
        context,
        title: 'Invalid Number',
        message: 'Please enter a valid UK mobile number.',
      );
      return;
    }

    final fullPhone =
        '+44${number.startsWith('0') ? number.substring(1) : number}';

    setState(() => _isLoading = true);

    await _authService.sendOtp(
      phoneNumber: fullPhone,
      onCodeSent: (verificationId, resendToken) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => OtpVerificationScreen(
              verificationId: verificationId,
              phoneNumber: fullPhone,
              localMobileNumber: number,
              resendToken: resendToken,
            ),
          ),
        );
      },
      onAutoVerified: () {
        if (!mounted) return;
        setState(() => _isLoading = false);
        // auth state listener in AppLaunchCoordinator handles navigation
      },
      onError: (message) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        GoOutsSheet.error(
          context,
          title: 'Verification Failed',
          message: message,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: _primary,
        body: Stack(
          children: [
            SafeArea(
              child: SingleChildScrollView(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 14),

                      // Brand header
                      const Text(
                        'GoOuts Lead',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),

                      const SizedBox(height: 40),

                      // Heading
                      const Text(
                        'Enter your mobile number',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          height: 1.2,
                        ),
                      ),

                      const SizedBox(height: 10),

                      Text(
                        "We'll send you a verification code.",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.9),
                          height: 1.4,
                        ),
                      ),

                      const SizedBox(height: 30),

                      // Phone input row
                      Row(
                        children: [
                          // UK flag + code
                          Container(
                            height: 64,
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.2)),
                            ),
                            child: const Row(
                              children: [
                                Text('🇬🇧',
                                    style: TextStyle(fontSize: 22)),
                                SizedBox(width: 8),
                                Text(
                                  '+44',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Phone number input
                          Expanded(
                            child: Container(
                              height: 64,
                              clipBehavior: Clip.hardEdge,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: TextField(
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                                maxLength: 11,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                  letterSpacing: 1.2,
                                ),
                                decoration: const InputDecoration(
                                  counterText: '',
                                  hintText: '07xxxxxxxxx',
                                  hintStyle: TextStyle(
                                    fontSize: 18,
                                    color: Colors.black38,
                                    letterSpacing: 1.2,
                                  ),
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 18),
                                ),
                                onSubmitted: (_) => _continue(),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Continue button
                      SizedBox(
                        width: double.infinity,
                        height: 60,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _continue,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: _primary,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: _primary,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : const Text(
                                  'Continue',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      Center(
                        child: GestureDetector(
                          onTap: () => showPreAuthSupportSheet(
                            context,
                            accountType: 'driver',
                          ),
                          child: const Text(
                            'Having trouble? Get help',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white70,
                              decoration: TextDecoration.underline,
                              decorationColor: Colors.white54,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

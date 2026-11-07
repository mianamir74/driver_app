// ─────────────────────────────────────────────────────────────────────────────
//  Sign Up a Driver. Added 25 October 2026 (GoOuts Lead version 1.1).
//
//  Drivers meet other drivers at pickup points, so this screen lets them sign
//  someone up on the spot: the other driver scans the QR code with their own
//  phone, lands on goouts.co.uk/join.html with this driver's referral code,
//  downloads the app and registers. Registration has to happen on the new
//  driver's own phone because it needs their SMS code, selfie and ID.
//  The WhatsApp invite (built in message) is still one tap away.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../referral/referral_link_screen.dart';

const Color _blue = Color(0xFF0392CA);
const Color _ink = Color(0xFF1C1C1C);
const Color _muted = Color(0xFF6B7280);

class SignUpDriverScreen extends StatelessWidget {
  const SignUpDriverScreen({super.key, required this.collection});

  /// drivers or cab_drivers, the signed in driver's own collection.
  final String collection;

  static String _codeOf(Map<String, dynamic>? d) {
    if (d == null) return '';
    final details = d['referralDetails'];
    for (final v in [
      d['ownReferralCode'],
      d['referralCode'],
      details is Map ? details['ownReferralCode'] : null,
    ]) {
      final s = (v ?? '').toString().trim().toUpperCase();
      if (s.isNotEmpty) return s;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        backgroundColor: _blue,
        foregroundColor: Colors.white,
        title: const Text('Sign Up a Driver',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: uid == null
          ? const Center(child: Text('Please log in again.'))
          : FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              future: FirebaseFirestore.instance
                  .collection(collection)
                  .doc(uid)
                  .get(),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final code = _codeOf(snap.data!.data());
                final link =
                    'https://www.goouts.co.uk/join.html?ref=${Uri.encodeComponent(code)}';
                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                  children: [
                    const Text('Sign them up on the spot',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: _ink)),
                    const SizedBox(height: 6),
                    const Text(
                      'Ask the driver to scan this code with their phone '
                      'camera. It opens the download page with your referral '
                      'code ready.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13.5, color: _muted, height: 1.45),
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: const [
                            BoxShadow(
                                color: Color(0x14000000),
                                blurRadius: 12,
                                offset: Offset(0, 4)),
                          ],
                        ),
                        child: code.isEmpty
                            ? const SizedBox(
                                width: 220,
                                height: 220,
                                child: Center(
                                  child: Text(
                                    'Your referral code is being set up. '
                                    'Open Invite on WhatsApp once, then '
                                    'come back.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: _muted),
                                  ),
                                ),
                              )
                            : QrImageView(
                                data: link,
                                size: 240,
                                eyeStyle: const QrEyeStyle(
                                    eyeShape: QrEyeShape.square, color: _ink),
                                dataModuleStyle: const QrDataModuleStyle(
                                    dataModuleShape: QrDataModuleShape.square,
                                    color: _ink),
                              ),
                      ),
                    ),
                    if (code.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      const Text('Your referral code',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: _muted)),
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: code));
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Code copied')));
                        },
                        child: Text(code,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 30,
                                letterSpacing: 3,
                                fontWeight: FontWeight.w800,
                                color: _blue)),
                      ),
                      const SizedBox(height: 4),
                      const Text('Tap to copy. They enter it when they register.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: _muted)),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 54,
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                                builder: (_) => const ReferralLinkScreen())),
                        icon: const Icon(Icons.chat_rounded),
                        label: const Text('Invite on WhatsApp instead',
                            style: TextStyle(
                                fontSize: 15.5, fontWeight: FontWeight.w700)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'You earn tier based residual income on the base fare of '
                      'every driver you sign up. No sign up bonus is paid for '
                      'drivers. T&Cs apply.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: _muted, height: 1.5),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

// Set or reset PIN after SMS login. Added 25 October 2026.
//
// WHY: accounts created before 16 Oct 2026 never got a working PIN (Firebase
// rejected the 4 digit password). "Forgot PIN?" only logged people in by SMS
// and never let them set a new PIN, so PIN login failed for those users
// forever. After every SMS login of an existing account we now ask for a PIN
// when the account has none, or when the user came through "Forgot PIN?".

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../services/activity_log_service.dart';
import 'pin_password.dart';

bool userHasPin(User user) =>
    user.providerData.any((UserInfo p) => p.providerId == 'password');

Future<void> savePinForUser(User user, String pin) async {
  final String phone = user.phoneNumber ?? '';
  final String email =
      '${phone.replaceAll('+', '').replaceAll(' ', '')}@goouts.app';
  final String pwd = pinToFirebasePassword(pin);
  if (userHasPin(user)) {
    await user.updatePassword(pwd);
  } else {
    try {
      await user.linkWithCredential(
          EmailAuthProvider.credential(email: email, password: pwd));
    } on FirebaseAuthException catch (e) {
      if (e.code == 'provider-already-linked') {
        await user.updatePassword(pwd);
      } else {
        rethrow;
      }
    }
  }
  await user.reload();
  await ActivityLogService.log('pin_reset');
}

/// Shows the Set PIN dialog. Returns when the PIN is saved or skipped.
Future<void> promptSetPin(BuildContext context, User user,
    {required bool isReset}) async {
  final TextEditingController pin1 = TextEditingController();
  final TextEditingController pin2 = TextEditingController();
  String? error;
  bool saving = false;

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext ctx) {
      return StatefulBuilder(builder: (BuildContext ctx, setLocal) {
        Future<void> save() async {
          final String a = pin1.text.trim();
          final String b = pin2.text.trim();
          if (!RegExp(r'^\d{4}$').hasMatch(a)) {
            setLocal(() => error = 'Enter a 4 digit PIN');
            return;
          }
          if (a != b) {
            setLocal(() => error = 'PINs do not match');
            return;
          }
          setLocal(() {
            saving = true;
            error = null;
          });
          try {
            await savePinForUser(user, a);
            if (ctx.mounted) Navigator.of(ctx).pop();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text(
                      'PIN saved. Next time log in with your number and PIN.')));
            }
          } on FirebaseAuthException catch (e) {
            await ActivityLogService.log('pin_reset_failed',
                details: <String, dynamic>{'code': e.code});
            setLocal(() {
              saving = false;
              error = 'Could not save PIN (${e.code}). Please try again.';
            });
          } catch (e) {
            setLocal(() {
              saving = false;
              error = 'Could not save PIN. Please try again.';
            });
          }
        }

        InputDecoration deco(String label) => InputDecoration(
              labelText: label,
              counterText: '',
              border: const OutlineInputBorder(),
            );

        return AlertDialog(
          title: Text(isReset ? 'Set a new PIN' : 'Create your PIN'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text(
                  'Choose a 4 digit PIN so you can log in quickly next time without an SMS code.'),
              const SizedBox(height: 16),
              TextField(
                controller: pin1,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 4,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly
                ],
                decoration: deco('New PIN'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: pin2,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 4,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly
                ],
                decoration: deco('Confirm PIN'),
              ),
              if (error != null) ...<Widget>[
                const SizedBox(height: 8),
                Text(error!, style: const TextStyle(color: Colors.red)),
              ],
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: saving ? null : () => Navigator.of(ctx).pop(),
              child: const Text('Later'),
            ),
            FilledButton(
              onPressed: saving ? null : save,
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save PIN'),
            ),
          ],
        );
      });
    },
  );
}

// User activity log. Added 16 October 2026.
//
// Writes one record per important account event to the top level
// Firestore collection `user_activity_logs`, so support can see what
// happened to an account (registration, logins, logouts, PIN problems).
//
// Rules (admin_panel/firestore.rules) allow a signed in user to CREATE a
// record for their own uid only. Nobody can edit or delete a record from
// the app, and only admins can read them.
//
// Events from before sign in (wrong OTP, wrong PIN) cannot be written here
// because there is no signed in user yet. Those are recorded by Firebase
// "User activity logging" in Google Cloud Logging instead.
//
// Logging must never break the app, so every failure is swallowed.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class ActivityLogService {
  ActivityLogService._();

  static Future<void> log(
    String event, {
    Map<String, dynamic> details = const <String, dynamic>{},
  }) async {
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      await FirebaseFirestore.instance
          .collection('user_activity_logs')
          .add(<String, dynamic>{
        'uid': user.uid,
        'phone': user.phoneNumber ?? '',
        'event': event,
        'app': 'enroll',
        'platform': defaultTargetPlatform.name,
        'details': details,
        'createdAt': FieldValue.serverTimestamp(),
      }).timeout(const Duration(seconds: 5));
    } catch (_) {
      // Never let logging break a user flow.
    }
  }
}

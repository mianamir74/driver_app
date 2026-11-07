// ─────────────────────────────────────────────────────────────────────────────
//  Driver home: £3,000 banner, Sign Up a Business button and My Businesses.
//  Added 25 October 2026 (GoOuts Lead version 1.1).
//
//  Reads venue_referrals where referrerUid is the signed in driver. Those
//  rows are written only by the venue_bonus.js Cloud Functions.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../legal/terms_and_conditions_screen.dart';
import 'sign_up_business_screen.dart';
import 'sign_up_driver_screen.dart';

const Color _blue = Color(0xFF0392CA);
const Color _ink = Color(0xFF1C1C1C);
const Color _muted = Color(0xFF6B7280);

Query<Map<String, dynamic>> _myVenues(String uid) => FirebaseFirestore.instance
    .collection('venue_referrals')
    .where('referrerUid', isEqualTo: uid)
    .orderBy('submittedAt', descending: true);

class _VenueStatus {
  final String label;
  final String detail;
  final Color fg;
  final Color bg;
  const _VenueStatus(this.label, this.detail, this.fg, this.bg);
}

_VenueStatus _statusOf(Map<String, dynamic> r) {
  final status = (r['status'] ?? 'submitted').toString();
  final tx = (r['txCount'] as num?)?.toInt() ?? 0;
  final need = (r['requiredTransactions'] as num?)?.toInt() ?? 3;
  final amount = (r['bonusAmount'] as num?)?.toInt() ?? 25;
  switch (status) {
    case 'qualified':
      return _VenueStatus('£$amount earned', '$need of $need transactions',
          const Color(0xFF1B8F3A), const Color(0xFFE8F5E9));
    case 'live':
      return _VenueStatus('Live', '$tx of $need transactions',
          const Color(0xFF0B6FB0), const Color(0xFFE3F2FD));
    case 'approved':
      return const _VenueStatus('Approved', 'Going live soon',
          Color(0xFF555555), Color(0xFFF1F3F5));
    case 'rejected':
      return const _VenueStatus('Not accepted', 'GoOuts could not accept it',
          Color(0xFFB42318), Color(0xFFFEE4E2));
    case 'expired':
      return _VenueStatus('No bonus', 'Did not reach $need transactions in time',
          const Color(0xFF555555), const Color(0xFFF1F3F5));
    default:
      return _VenueStatus(
          'Submitted',
          r['moreInfoNeeded'] == true
              ? 'GoOuts needs more details, we will be in touch'
              : 'Waiting for GoOuts check',
          const Color(0xFFB26A00),
          const Color(0xFFFFF4E0));
  }
}

/// The block shown on the driver home screen above Quick Actions.
class SignUpBusinessPanel extends StatelessWidget {
  const SignUpBusinessPanel({super.key, required this.collection});

  /// drivers or cab_drivers: where the signed in driver's record lives.
  final String collection;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // £3,000 banner
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFC93C), Color(0xFFFF9F1C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text.rich(
            TextSpan(children: [
              TextSpan(text: 'Earn up to '),
              TextSpan(
                  text: '£3,000',
                  style: TextStyle(color: Colors.white)),
              TextSpan(text: ' a year in residual income'),
            ]),
            style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1B1B2F),
                height: 1.2),
          ),
          const SizedBox(height: 6),
          const Text(
            'Sign up businesses and invite drivers before someone else does.',
            style: TextStyle(fontSize: 13, color: Color(0xFF3A2A00)),
          ),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () => showTermsSheet(context),
            child: const Text('T&Cs apply',
                style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF5A4100),
                    decoration: TextDecoration.underline)),
          ),
        ]),
      ),
      const SizedBox(height: 14),
      // Main button
      Material(
        color: _blue,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => const SignUpBusinessScreen())),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.storefront_rounded,
                    color: Colors.white),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Sign Up a Business',
                          style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: Colors.white)),
                      SizedBox(height: 2),
                      Text('£25 bonus + residual on every venue',
                          style: TextStyle(fontSize: 12.5, color: Colors.white)),
                    ]),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white),
            ]),
          ),
        ),
      ),
      const SizedBox(height: 12),
      // Sign Up a Driver: on the spot with a QR code, or a WhatsApp invite.
      Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _blue, width: 2),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => SignUpDriverScreen(collection: collection))),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.two_wheeler_rounded, color: _blue),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Sign Up a Driver',
                          style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: _blue)),
                      SizedBox(height: 2),
                      Text('On the spot with a QR code, or send an invite',
                          style: TextStyle(fontSize: 12.5, color: _blue)),
                    ]),
              ),
              const Icon(Icons.chevron_right_rounded, color: _blue),
            ]),
          ),
        ),
      ),
      if (uid != null) ...[
        const SizedBox(height: 14),
        _TierStats(collection: collection, uid: uid),
        const SizedBox(height: 14),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _myVenues(uid).limit(4).snapshots(),
          builder: (context, snap) {
            final docs = snap.data?.docs ?? const [];
            if (docs.isEmpty) return const SizedBox.shrink();
            return _VenueCard(
              title: 'My Businesses',
              docs: docs,
              onSeeAll: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => const MyBusinessesScreen())),
            );
          },
        ),
      ],
    ]);
  }
}

/// Four boxes: how many drivers and businesses signed up, and the residual
/// tier for each. Tiers follow residual_tiers.js: 1 to 5 = 2%, 6 to 10 = 3%,
/// 11 and over = 5%. The counts are driverReferralCount and
/// merchantReferralCount, kept up to date by Cloud Functions.
class _TierStats extends StatelessWidget {
  const _TierStats({required this.collection, required this.uid});
  final String collection;
  final String uid;

  static (String, String, String) _tier(int n) {
    if (n >= 11) return ('5%', 'Gold', 'Top tier');
    if (n >= 6) return ('3%', 'Silver', '${11 - n} more to Gold');
    return ('2%', 'Bronze', '${6 - n} more to Silver');
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection(collection)
          .doc(uid)
          .snapshots(),
      builder: (context, snap) {
        final d = snap.data?.data() ?? const <String, dynamic>{};
        final drivers = (d['driverReferralCount'] as num?)?.toInt() ?? 0;
        final venues = (d['merchantReferralCount'] as num?)?.toInt() ?? 0;
        final dt = _tier(drivers);
        final vt = _tier(venues);
        Widget box(String value, String label, [String? sub]) => Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE8EEF3)),
                ),
                child: Column(children: [
                  Text(value,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: _blue)),
                  const SizedBox(height: 3),
                  Text(label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 11, color: _muted)),
                  if (sub != null) ...[
                    const SizedBox(height: 2),
                    Text(sub,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFB26A00))),
                  ],
                ]),
              ),
            );
        return Column(children: [
          Row(children: [
            box('$drivers', 'Drivers signed up'),
            const SizedBox(width: 10),
            box(dt.$1, 'Driver tier · ${dt.$2}', dt.$3),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            box('$venues', 'Businesses signed up'),
            const SizedBox(width: 10),
            box(vt.$1, 'Business tier · ${vt.$2}', vt.$3),
          ]),
        ]);
      },
    );
  }
}

class _VenueCard extends StatelessWidget {
  const _VenueCard({required this.title, required this.docs, this.onSeeAll});
  final String title;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8EEF3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(title,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w800, color: _ink)),
          ),
          if (onSeeAll != null)
            TextButton(onPressed: onSeeAll, child: const Text('See all')),
        ]),
        for (int i = 0; i < docs.length; i++) ...[
          _VenueRow(data: docs[i].data()),
          if (i < docs.length - 1)
            const Divider(height: 1, color: Color(0xFFEEF1F5)),
        ],
      ]),
    );
  }
}

class _VenueRow extends StatelessWidget {
  const _VenueRow({required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final s = _statusOf(data);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text((data['venueName'] ?? '').toString(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600, color: _ink)),
            const SizedBox(height: 2),
            Text(s.detail,
                style: const TextStyle(fontSize: 12, color: _muted)),
          ]),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
              color: s.bg, borderRadius: BorderRadius.circular(20)),
          child: Text(s.label,
              style: TextStyle(
                  fontSize: 11.5, fontWeight: FontWeight.w700, color: s.fg)),
        ),
      ]),
    );
  }
}

/// Full list of every business the driver has signed up.
class MyBusinessesScreen extends StatelessWidget {
  const MyBusinessesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        backgroundColor: _blue,
        foregroundColor: Colors.white,
        title: const Text('My Businesses',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _blue,
        foregroundColor: Colors.white,
        onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => const SignUpBusinessScreen())),
        icon: const Icon(Icons.add_business_rounded),
        label: const Text('Sign Up a Business'),
      ),
      body: uid == null
          ? const Center(child: Text('Please log in again.'))
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _myVenues(uid).snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return const Center(
                      child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Could not load your businesses. '
                        'Please try again later.'),
                  ));
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snap.data!.docs;
                final earned = docs
                    .where((d) => d.data()['bonusStatus'] == 'paid')
                    .fold<num>(0, (a, d) => a + ((d.data()['bonusPaid'] as num?) ?? 0));
                final live = docs
                    .where((d) => ['live', 'qualified']
                        .contains(d.data()['status']))
                    .length;
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  children: [
                    Row(children: [
                      _stat('${docs.length}', 'Signed up'),
                      const SizedBox(width: 10),
                      _stat('$live', 'Live'),
                      const SizedBox(width: 10),
                      _stat('£${earned.toStringAsFixed(0)}', 'Bonus earned'),
                    ]),
                    const SizedBox(height: 16),
                    if (docs.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 40),
                        child: Text(
                          'No businesses yet. Tap Sign Up a Business to add '
                          'your first one.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: _muted),
                        ),
                      )
                    else
                      _VenueCard(title: 'All businesses', docs: docs),
                    const SizedBox(height: 12),
                    const Text(
                      'You earn the £25 bonus once a business is live and has '
                      'completed 3 genuine customer transactions within 90 '
                      'days of going live. T&Cs apply.',
                      style: TextStyle(fontSize: 12, color: _muted, height: 1.5),
                    ),
                  ],
                );
              },
            ),
    );
  }

  Widget _stat(String value, String label) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(children: [
            Text(value,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800, color: _blue)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 11.5, color: _muted)),
          ]),
        ),
      );
}

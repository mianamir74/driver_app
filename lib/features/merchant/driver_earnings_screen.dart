import 'package:auto_size_text/auto_size_text.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DriverEarningsScreen extends StatefulWidget {
  const DriverEarningsScreen({super.key});

  @override
  State<DriverEarningsScreen> createState() => _DriverEarningsScreenState();
}

class _DriverEarningsScreenState extends State<DriverEarningsScreen> {
  // ── Brand ──────────────────────────────────────────────────────────────────
  static const Color _blue = Color(0xFF0392CA);
  static const Color _navy = Color(0xFF0D1B3E);
  static const Color _green = Color(0xFF10B981);
  static const Color _amber = Color(0xFFF59E0B);
  static const Color _purple = Color(0xFF7C3AED);
  static const Color _textPrimary = Color(0xFF1C1C1C);
  static const Color _textSecondary = Color(0xFF6B7280);
  static const Color _border = Color(0xFFE5E7EB);
  static const Color _bg = Color(0xFFF8FAFF);

  // ── State ──────────────────────────────────────────────────────────────────
  bool _loading = true;
  List<Map<String, dynamic>> _referredDrivers = [];
  int _totalReferred = 0;
  int _activeDrivers = 0;
  double _totalEarningsAllTime = 0;
  double _thisMonthEarnings = 0;

  // ── Tier config ────────────────────────────────────────────────────────────
  static const List<Map<String, dynamic>> _tiers = [
    {
      'tier': 1,
      'label': 'Tier 1',
      'min': 1,
      'max': 5,
      'commission': 3.0,
      'color': Color(0xFF0392CA),
      'icon': Icons.emoji_events_outlined,
    },
    {
      'tier': 2,
      'label': 'Tier 2',
      'min': 6,
      'max': 10,
      'commission': 4.0,
      'color': Color(0xFF7C3AED),
      'icon': Icons.workspace_premium_outlined,
    },
    {
      'tier': 3,
      'label': 'Tier 3',
      'min': 11,
      'max': 999,
      'commission': 5.0,
      'color': Color(0xFFF59E0B),
      'icon': Icons.military_tech_outlined,
    },
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final snap = await FirebaseFirestore.instance
          .collection('drivers')
          .where('referredBy', isEqualTo: uid)
          .orderBy('submittedAt', descending: true)
          .get();

      final drivers = snap.docs.map((d) {
        final data = d.data();
        data['docId'] = d.id;
        return data;
      }).toList();

      final active = drivers
          .where((d) =>
              (d['status'] ?? '').toString().toUpperCase() == 'APPROVED')
          .length;

      double allTime = 0;
      double thisMonth = 0;
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);

      for (final d in drivers) {
        final docId = d['docId'] as String;
        try {
          final commSnap = await FirebaseFirestore.instance
              .collection('drivers')
              .doc(docId)
              .collection('driver_commissions')
              .get();
          double driverTotal = 0;
          double driverMonth = 0;
          for (final c in commSnap.docs) {
            final cd = c.data();
            final amount = (cd['amount'] as num?)?.toDouble() ?? 0.0;
            final ts = cd['createdAt'];
            DateTime? date;
            if (ts is Timestamp) date = ts.toDate();
            driverTotal += amount;
            if (date != null && date.isAfter(startOfMonth)) {
              driverMonth += amount;
            }
          }
          d['commissionEarned'] = driverTotal;
          d['commissionThisMonth'] = driverMonth;
          allTime += driverTotal;
          thisMonth += driverMonth;
        } catch (_) {
          d['commissionEarned'] = 0.0;
          d['commissionThisMonth'] = 0.0;
        }
      }

      if (mounted) {
        setState(() {
          _referredDrivers = drivers;
          _totalReferred = drivers.length;
          _activeDrivers = active;
          _totalEarningsAllTime = allTime;
          _thisMonthEarnings = thisMonth;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<String, dynamic> _currentTier() {
    for (final t in _tiers.reversed) {
      if (_activeDrivers >= (t['min'] as int)) return t;
    }
    return _tiers[0];
  }

  Map<String, dynamic>? _nextTier() {
    final cur = _currentTier();
    final idx = _tiers.indexOf(cur);
    if (idx < _tiers.length - 1) return _tiers[idx + 1];
    return null;
  }

  double _tierProgress() {
    final cur = _currentTier();
    final min = cur['min'] as int;
    final max = cur['max'] as int;
    if (max >= 999) return 1.0;
    final progress = (_activeDrivers - min + 1) / (max - min + 1);
    return progress.clamp(0.0, 1.0);
  }

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'APPROVED':
        return _green;
      case 'PENDING':
        return _amber;
      case 'REJECTED':
        return Colors.red;
      default:
        return _textSecondary;
    }
  }

  String _statusLabel(String status) {
    switch (status.toUpperCase()) {
      case 'APPROVED':
        return 'Active';
      case 'PENDING':
        return 'Pending';
      case 'REJECTED':
        return 'Rejected';
      default:
        return status;
    }
  }

  String _fmt(double v) => NumberFormat.currency(
        locale: 'en_GB',
        symbol: '£',
        decimalDigits: 2,
      ).format(v);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _textPrimary,
        elevation: 0,
        title: const Text(
          'My Earnings',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: _blue),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _tierCard(),
                    const SizedBox(height: 16),
                    _earningsSummaryRow(),
                    const SizedBox(height: 24),
                    _allTiersRow(),
                    const SizedBox(height: 24),
                    const Text(
                      'Referred Drivers',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: _textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'You earn ${(_currentTier()['commission'] as double).toStringAsFixed(0)}% of GoOuts\' monthly profit from each driver you refer.',
                      style: const TextStyle(
                        fontSize: 13,
                        color: _textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (_referredDrivers.isEmpty)
                      _emptyState()
                    else
                      ..._referredDrivers
                          .map((d) => _driverCard(d))
                          .toList(),
                    const SizedBox(height: 24),
                    _howItWorksCard(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _tierCard() {
    final tier = _currentTier();
    final next = _nextTier();
    final progress = _tierProgress();
    final tierColor = tier['color'] as Color;
    final commission = tier['commission'] as double;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_navy, tierColor.withValues(alpha: 0.85)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _navy.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(tier['icon'] as IconData,
                        color: Colors.white, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      tier['label'] as String,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                '$_activeDrivers active',
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '${commission.toStringAsFixed(0)}% commission',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'of GoOuts profit from each referred driver',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white70,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          if (next != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$_activeDrivers / ${next['min'] as int} to ${next['label']}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '${(next['commission'] as double).toStringAsFixed(0)}% at ${next['label']}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(Colors.white),
                minHeight: 6,
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star_rounded, color: _amber, size: 16),
                  SizedBox(width: 6),
                  Text(
                    'Maximum tier reached — 5% forever',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _earningsSummaryRow() {
    return Row(
      children: [
        Expanded(
          child: _summaryCard(
            label: 'This Month',
            value: _fmt(_thisMonthEarnings),
            icon: Icons.calendar_month_rounded,
            color: _blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _summaryCard(
            label: 'All Time',
            value: _fmt(_totalEarningsAllTime),
            icon: Icons.account_balance_wallet_outlined,
            color: _green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _summaryCard(
            label: 'Total Referred',
            value: '$_totalReferred',
            icon: Icons.people_rounded,
            color: _purple,
          ),
        ),
      ],
    );
  }

  Widget _summaryCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 10),
          AutoSizeText(
            value,
            maxLines: 1,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: _textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _allTiersRow() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Commission Structure',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: _tiers.map((t) {
              final isCurrent = _currentTier()['tier'] == t['tier'];
              final color = t['color'] as Color;
              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: t == _tiers.last ? 0 : 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 12),
                  decoration: BoxDecoration(
                    color: isCurrent
                        ? color.withValues(alpha: 0.1)
                        : const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isCurrent
                          ? color.withValues(alpha: 0.4)
                          : _border,
                      width: isCurrent ? 1.5 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        t['label'] as String,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isCurrent ? color : _textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${(t['commission'] as double).toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: isCurrent ? color : _textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${t['min']}–${t['max'] as int >= 999 ? '∞' : t['max']} drivers',
                        style: TextStyle(
                          fontSize: 10,
                          color: isCurrent
                              ? color.withValues(alpha: 0.7)
                              : _textSecondary,
                        ),
                      ),
                      if (isCurrent) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'YOU',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _driverCard(Map<String, dynamic> d) {
    final firstName = (d['firstName'] ?? '').toString().trim();
    final surname = (d['surname'] ?? d['lastName'] ?? '').toString().trim();
    final name = [firstName, surname].where((s) => s.isNotEmpty).join(' ');
    final displayName = name.isNotEmpty ? name : 'Driver';
    final vehicleType = (d['vehicleType'] ?? d['driverType'] ?? '').toString();
    final city = (d['city'] ?? '').toString();
    final status = (d['status'] ?? 'PENDING').toString();
    final commission = (d['commissionEarned'] as num?)?.toDouble() ?? 0.0;
    final monthlyComm = (d['commissionThisMonth'] as num?)?.toDouble() ?? 0.0;
    final ts = d['submittedAt'];
    String dateStr = '';
    if (ts is Timestamp) {
      dateStr = DateFormat('d MMM yyyy').format(ts.toDate());
    }
    final statusColor = _statusColor(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _blue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.person_rounded, color: _blue, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        displayName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _textPrimary,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _statusLabel(status),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  [if (vehicleType.isNotEmpty) vehicleType, if (city.isNotEmpty) city]
                      .join(' · '),
                  style: const TextStyle(fontSize: 12, color: _textSecondary),
                ),
                if (dateStr.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Joined $dateStr',
                    style: const TextStyle(fontSize: 11, color: _textSecondary),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    _miniStat('This month', _fmt(monthlyComm), _blue),
                    const SizedBox(width: 12),
                    _miniStat('All time', _fmt(commission), _green),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: _textSecondary)),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _emptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: _blue.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.people_outline, color: _blue, size: 30),
          ),
          const SizedBox(height: 16),
          const Text(
            'No drivers referred yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Share your referral link with other drivers. Every driver who joins using your code earns you residual commission every month.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: _textSecondary, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _howItWorksCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _navy,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'How your earnings work',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          _howStep('1', 'Share your referral link or code with other drivers.'),
          _howStep('2', 'They register on GoOuts using your referral code.'),
          _howStep('3', 'Once approved and active, they count towards your tier.'),
          _howStep('4', 'You earn a % of GoOuts profit generated by each referred driver.'),
          _howStep('5', 'Refer more drivers to unlock higher tiers and bigger commissions.'),
        ],
      ),
    );
  }

  Widget _howStep(String num, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: _blue,
              borderRadius: BorderRadius.circular(7),
            ),
            alignment: Alignment.center,
            child: Text(
              num,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.white70,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

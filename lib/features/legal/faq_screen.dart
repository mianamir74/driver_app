import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:auto_size_text/auto_size_text.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FAQ Screen  —  GoOuts Lead (enrolment / referral app)
//
// Loads FAQ items from Firestore collection `driver_lead_faqs`.
// Fields: question, answer, category, order, isActive.
// Falls back to the hardcoded defaults below when the collection is empty or
// unreachable. Managed from Admin Panel → Driver FAQs → GoOuts Lead.
//
// IMPORTANT: the collection name and the `isActive` field name must stay in
// step with _DriverFaqsPage in admin_panel/lib/admin_dashboard.dart. Until
// July 2026 this screen read a collection called `faq` while the admin panel
// wrote to `driver_faqs` using a field called `active`, so nothing an admin
// entered ever reached the app and the defaults below were always shown.
// ─────────────────────────────────────────────────────────────────────────────

const String kDriverLeadFaqCollection = 'driver_lead_faqs';

class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  static const Color _goOutsBlue = Color(0xFF0392CA);

  /// Category display order. Anything not listed is appended at the end.
  static const List<String> _categoryOrder = [
    'Getting Started',
    'Registration',
    'Verification',
    'Referrals',
    'Earnings',
    'Account',
    'Support',
  ];

  // ── Hardcoded fallback FAQs ────────────────────────────────────────────────
  // Every figure and screen name below has been checked against the app code.
  // Commission tiers come from features/merchant/driver_earnings_screen.dart.
  static const List<_FaqItem> _defaults = [
    // ── Getting Started ──────────────────────────────────────────────────────
    _FaqItem(
      category: 'Getting Started',
      question: 'What is GoOuts?',
      answer:
          'GoOuts is a cashback and delivery platform launching across the '
          'United Kingdom and Northern Ireland. This app is where you register '
          'your interest early, secure your place, and start building your '
          'referral network before the platform goes live in your area.',
    ),
    _FaqItem(
      category: 'Getting Started',
      question: 'Is GoOuts live yet?',
      answer:
          'Not yet. GoOuts is in its early access phase, so no live deliveries '
          'or payments happen inside this app at the moment. Everyone who '
          'registers now receives priority access and a notification the moment '
          'we go live in their area.',
    ),
    _FaqItem(
      category: 'Getting Started',
      question: 'Why should I register now rather than wait for launch?',
      answer:
          'Two reasons. Your place in the queue is set by when you register, so '
          'early registrations are onboarded first. More importantly, everyone '
          'you refer stays linked to you permanently, which means the network '
          'you build now is the network you earn from on day one.',
    ),

    // ── Registration ─────────────────────────────────────────────────────────
    _FaqItem(
      category: 'Registration',
      question: 'Which role should I choose?',
      answer:
          'Choose Delivery Driver if you will be delivering food and parcels. '
          'Choose Rider Driver if you will be carrying passengers in a car. '
          'Choose Business Partner if you own or manage a restaurant, cafe, shop '
          'or takeaway that wants to join GoOuts.',
    ),
    _FaqItem(
      category: 'Registration',
      question: 'How do I register as a Delivery Driver?',
      answer:
          'Select Delivery Driver on the role selection screen, enter your '
          'personal details and address, upload a selfie and a valid identity '
          'document, then submit. Our team reviews your submission and you will '
          'be notified once your profile is approved.',
    ),
    _FaqItem(
      category: 'Registration',
      question: 'How do I register as a Rider Driver?',
      answer:
          'Select Rider Driver, complete your personal details, then upload a '
          'selfie together with clear photos of the front and the back of your '
          'driving licence. Both sides are required because we need to confirm '
          'the licence categories you hold.',
    ),
    _FaqItem(
      category: 'Registration',
      question: 'How do I register as a Business Partner?',
      answer:
          'Select Business Partner and you will be asked for your business name, '
          'company number, trading address and supporting documents. Once you '
          'submit, our partnerships team reviews the application and will '
          'contact you directly.',
    ),
    _FaqItem(
      category: 'Registration',
      question: 'Can I correct my details after I have submitted them?',
      answer:
          'Yes. Open the menu, go to your profile, and edit any field that needs '
          'changing. If your identity document has already been approved you '
          'will need to contact support before it can be replaced.',
    ),

    // ── Verification ─────────────────────────────────────────────────────────
    _FaqItem(
      category: 'Verification',
      question: 'Why do I need to upload identity documents?',
      answer:
          'Identity verification is a legal requirement for anyone carrying '
          'goods or passengers for payment. We ask for a selfie and a government '
          'issued photo document so we can confirm you are who you say you are '
          'and that you have the right to work in the United Kingdom.',
    ),
    _FaqItem(
      category: 'Verification',
      question: 'Which documents are accepted?',
      answer:
          'A valid passport or a full driving licence. The document must be in '
          'date and the photo page must be fully visible with all four corners '
          'in frame. Rider Drivers must supply both the front and the back of '
          'their driving licence.',
    ),
    _FaqItem(
      category: 'Verification',
      question: 'How long does verification take?',
      answer:
          'Most submissions are checked automatically within a couple of '
          'minutes. If anything needs a human eye, a member of our team reviews '
          'it, which normally takes up to two working days. You will receive a '
          'notification either way.',
    ),
    _FaqItem(
      category: 'Verification',
      question: 'Why was my document rejected?',
      answer:
          'Almost always it is the photo rather than the document. The usual '
          'causes are blur from movement, glare from a light or a window, a '
          'corner outside the frame, or a name that does not match the one you '
          'registered with. Lay the document flat in daylight, retake the photo, '
          'and submit it again from your profile.',
    ),

    // ── Referrals ────────────────────────────────────────────────────────────
    _FaqItem(
      category: 'Referrals',
      question: 'How does the referral programme work?',
      answer:
          'Every registered user gets a unique referral code and a shareable '
          'link. When somebody registers using your code they are permanently '
          'linked to your network. From the referrals section you can see '
          'everyone you have invited, who has completed registration, and who is '
          'still pending.',
    ),
    _FaqItem(
      category: 'Referrals',
      question: 'Where do I find my referral code?',
      answer:
          'It is on your home screen and in the referrals section. Tap it to '
          'copy it, or use the share button to send your link straight to '
          'WhatsApp, a message or an email.',
    ),
    _FaqItem(
      category: 'Referrals',
      question: 'How do I remind somebody who has not finished registering?',
      answer:
          'Open your referrals list, find the person marked Pending, and tap '
          'Send Reminder. This opens WhatsApp with a message already written and '
          'addressed to them, so all you need to do is press send.',
    ),
    _FaqItem(
      category: 'Referrals',
      question: 'What does Joined Elsewhere mean?',
      answer:
          'It means the person you invited did complete their registration, but '
          'they entered somebody else’s referral code instead of yours, so '
          'they are not counted in your network. If you believe that is a '
          'mistake, contact support with their name and phone number.',
    ),
    _FaqItem(
      category: 'Referrals',
      question: 'Is there a limit on how many people I can refer?',
      answer:
          'No. There is no cap on the number of drivers or businesses you can '
          'bring to GoOuts, and no cap on your commission tier once you have '
          'reached the top of the scale.',
    ),

    // ── Earnings ─────────────────────────────────────────────────────────────
    _FaqItem(
      category: 'Earnings',
      question: 'How does referral commission actually work?',
      answer:
          'You earn a percentage of the profit GoOuts makes from each driver you '
          'referred, paid monthly for as long as that driver stays active. It is '
          'never taken out of the driver’s own earnings, so referring '
          'somebody costs them nothing at all.',
    ),
    _FaqItem(
      category: 'Earnings',
      question: 'What are the commission tiers?',
      answer:
          'There are three tiers, set by how many of your referred drivers are '
          'active. With 1 to 5 active drivers you earn 3 percent. With 6 to 10 '
          'you earn 4 percent. With 11 or more you earn 5 percent, which is the '
          'maximum and stays yours from then on. Your current tier and your '
          'progress towards the next one are shown in the earnings section.',
    ),
    _FaqItem(
      category: 'Earnings',
      question: 'When will I actually start being paid?',
      answer:
          'Referral commission begins once GoOuts is live in your area and your '
          'referred drivers start completing paid work. Nothing is payable '
          'during the early access phase because no commercial transactions are '
          'taking place yet.',
    ),
    _FaqItem(
      category: 'Earnings',
      question: 'Do I keep earning if I am not working myself?',
      answer:
          'Your commission is tied to the activity of the drivers you referred '
          'rather than your own. Full qualifying rules will be published before '
          'launch, and we will give you clear notice well in advance of any '
          'requirement coming into effect.',
    ),

    // ── Account ──────────────────────────────────────────────────────────────
    _FaqItem(
      category: 'Account',
      question: 'How do I log in?',
      answer:
          'GoOuts uses your phone number rather than a password. Enter your '
          'number on the login screen and we send you a single use code by text. '
          'Enter that code and you are in. There is no password to remember and '
          'nothing to reset.',
    ),
    _FaqItem(
      category: 'Account',
      question: 'My verification code has not arrived. What should I do?',
      answer:
          'Check that the number you entered is correct including the country '
          'code, make sure you have signal, and let the resend timer finish '
          'before asking for a new code. If it still does not arrive, your '
          'network may be filtering it, so try again on a different connection '
          'or contact support.',
    ),
    _FaqItem(
      category: 'Account',
      question: 'Can I have more than one account?',
      answer:
          'No. GoOuts allows one account per person, tied to your verified '
          'identity and phone number. Duplicate accounts break referral tracking '
          'and may be suspended. If you cannot get into your account, support '
          'can help rather than you starting again.',
    ),

    // ── Support ──────────────────────────────────────────────────────────────
    _FaqItem(
      category: 'Support',
      question: 'How do I contact GoOuts support?',
      answer:
          'Open the menu and tap Help and Support to raise a ticket from inside '
          'the app. You can choose a category, describe the issue and attach a '
          'photo if it helps. You can also email support@goouts.app. We aim to '
          'reply within one working day.',
    ),
    _FaqItem(
      category: 'Support',
      question: 'Is my personal data safe?',
      answer:
          'Your documents and personal details are stored encrypted and are only '
          'accessible to the small verification team that needs them. We do not '
          'sell your data and we do not share it with third parties except where '
          'the law requires it.',
    ),
  ];

  Future<List<_FaqItem>> _loadFaqs() async {
    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot =
          await FirebaseFirestore.instance
              .collection(kDriverLeadFaqCollection)
              .where('isActive', isEqualTo: true)
              .orderBy('order')
              .get();

      if (snapshot.docs.isEmpty) {
        return _defaults;
      }

      final List<_FaqItem> loaded = snapshot.docs
          .map((doc) {
            final data = doc.data();
            return _FaqItem(
              category:
                  (data['category'] ?? 'General').toString().trim().isEmpty
                      ? 'General'
                      : (data['category'] ?? 'General').toString().trim(),
              question: (data['question'] ?? '').toString().trim(),
              answer: (data['answer'] ?? '').toString().trim(),
            );
          })
          .where((item) => item.question.isNotEmpty && item.answer.isNotEmpty)
          .toList();

      // A collection full of blank rows should not produce an empty screen.
      return loaded.isEmpty ? _defaults : loaded;
    } catch (_) {
      // Firestore unavailable, offline, or the composite index is missing.
      return _defaults;
    }
  }

  /// Groups items by category, preserving [_categoryOrder] first and then any
  /// unrecognised categories in the order they were received.
  static List<_FaqSection> _group(List<_FaqItem> items) {
    final Map<String, List<_FaqItem>> buckets = <String, List<_FaqItem>>{};
    for (final item in items) {
      buckets.putIfAbsent(item.category, () => <_FaqItem>[]).add(item);
    }

    final List<String> ordered = <String>[
      ..._categoryOrder.where(buckets.containsKey),
      ...buckets.keys.where((k) => !_categoryOrder.contains(k)),
    ];

    return ordered
        .map((name) => _FaqSection(title: name, items: buckets[name]!))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const AutoSizeText(
          'FAQ',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
        centerTitle: true,
      ),
      body: FutureBuilder<List<_FaqItem>>(
        future: _loadFaqs(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: _goOutsBlue),
            );
          }

          final List<_FaqSection> sections =
              _group(snapshot.data ?? _defaults);

          // Flatten into a single list of rows so one ListView handles the
          // header, every category heading and every tile.
          final List<Widget> rows = <Widget>[_buildHeader()];
          for (final section in sections) {
            rows.add(_buildCategoryHeading(section.title));
            for (final item in section.items) {
              rows.add(Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _FaqTile(item: item),
              ));
            }
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
            itemCount: rows.length,
            itemBuilder: (context, index) => rows[index],
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Container(
        clipBehavior: Clip.antiAlias,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFBFDBFE)),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.help_outline_rounded, color: _goOutsBlue, size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Tap any question to see the answer. If you cannot find what '
                'you are looking for, contact us through Help and Support in '
                'the menu.',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF1E3A8A),
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryHeading(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 10, left: 2),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: Color(0xFF64748B),
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FAQ data model
// ─────────────────────────────────────────────────────────────────────────────

class _FaqItem {
  final String category;
  final String question;
  final String answer;

  const _FaqItem({
    required this.category,
    required this.question,
    required this.answer,
  });
}

class _FaqSection {
  final String title;
  final List<_FaqItem> items;

  const _FaqSection({required this.title, required this.items});
}

// ─────────────────────────────────────────────────────────────────────────────
// Expandable FAQ tile
// ─────────────────────────────────────────────────────────────────────────────

class _FaqTile extends StatefulWidget {
  const _FaqTile({required this.item});
  final _FaqItem item;

  @override
  State<_FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends State<_FaqTile> {
  static const Color _goOutsBlue = Color(0xFF0392CA);

  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _expanded ? _goOutsBlue : const Color(0xFFE5E7EB),
          width: _expanded ? 1.4 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: ExpansionTile(
          tilePadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          iconColor: _goOutsBlue,
          collapsedIconColor: Colors.black45,
          onExpansionChanged: (value) {
            if (!mounted) return;
            setState(() {
              _expanded = value;
            });
          },
          title: AutoSizeText(
            widget.item.question,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _expanded ? _goOutsBlue : const Color(0xFF1F2937),
              height: 1.4,
            ),
          ),
          children: [
            const Divider(height: 1, thickness: 1, color: Color(0xFFE5E7EB)),
            const SizedBox(height: 12),
            AutoSizeText(
              widget.item.answer,
              style: const TextStyle(
                fontSize: 13.5,
                color: Color(0xFF374151),
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

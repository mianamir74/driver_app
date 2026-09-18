import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'support_ticket_chat_screen.dart';
import 'my_tickets_screen.dart';
import 'package:driver_app/features/common/goouts_sheet.dart';

// ── Topic & sub-topic data ──────────────────────────────────────────────────
//
// 17 September 2026: restyled to match goouts_app's Contact Support screen
// (lib/screens/contact_support_screen.dart) — a real dropdown for Topic, and
// icon + description tiles for the sub-topic, instead of the old plain tile
// grid. Topics/sub-topics themselves stay driver/Lead-Partner specific
// (Registration, Verification, Referral, Technical, General) rather than
// copying goouts_app's consumer ones (Cashback, Card, KYC, Food Delivery),
// which do not apply here. No self-service/AI lookup step — that engine
// reads consumer wallet/cashback/KYC data that has no equivalent for a
// driver/business account, so this stays a straight ticket form like before.

final List<Map<String, String>> _topics = [
  {'label': '— Select a Topic —', 'value': ''},
  {'label': 'Registration',       'value': 'registration'},
  {'label': 'Verification',       'value': 'verification'},
  {'label': 'Referral & Rewards', 'value': 'referral'},
  {'label': 'Technical Issue',    'value': 'technical'},
  {'label': 'General',            'value': 'general'},
  {'label': 'Something Else',     'value': 'other'},
];

final Map<String, List<Map<String, String>>> _subTopics = {
  'registration': [
    {'label': 'Stuck During Registration', 'icon': 'error',    'desc': "I can't get past a step in sign-up"},
    {'label': 'Document Upload Issue',     'icon': 'upload',   'desc': "My ID or document won't upload"},
    {'label': 'Referral Code Problem',     'icon': 'gift',     'desc': "My referral code isn't being accepted"},
    {'label': 'Something Else',            'icon': 'help',     'desc': 'Another registration issue'},
  ],
  'verification': [
    {'label': 'Identity Check Failed',       'icon': 'cancel_doc', 'desc': 'My identity verification was rejected'},
    {'label': 'Approval Taking Too Long',    'icon': 'hourglass',  'desc': 'My account is still pending approval'},
    {'label': 'Account Rejected',            'icon': 'block',      'desc': 'My application was declined'},
    {'label': 'Something Else',              'icon': 'help',       'desc': 'Another verification issue'},
  ],
  'referral': [
    {'label': 'Reward Not Credited',        'icon': 'wallet', 'desc': "My referral reward hasn't appeared"},
    {'label': 'Referral Code Not Working',  'icon': 'gift',   'desc': "My code isn't being accepted by a new sign-up"},
    {'label': 'Something Else',             'icon': 'help',   'desc': 'Another referral question'},
  ],
  'technical': [
    {'label': 'App Crashing or Freezing',     'icon': 'warning',       'desc': 'The app closes or freezes unexpectedly'},
    {'label': 'Cannot Log In',                'icon': 'lock',          'desc': "I can't sign in to my account"},
    {'label': 'Notifications Not Working',    'icon': 'notifications', 'desc': "I'm not receiving order or app alerts"},
    {'label': 'Something Else',               'icon': 'help',          'desc': 'Another technical issue'},
  ],
  'general': [
    {'label': 'How GoOuts Works',     'icon': 'info',   'desc': 'A general question about the platform'},
    {'label': 'Delete My Account',    'icon': 'delete', 'desc': 'I want to close my account'},
    {'label': 'Change My Details',    'icon': 'edit',   'desc': 'I need to update my name, email or phone'},
    {'label': 'Something Else',       'icon': 'help',   'desc': 'Another general question'},
  ],
};

const Map<String, IconData> _topicIconMap = {
  'error':         Icons.error_outline_rounded,
  'upload':        Icons.upload_rounded,
  'gift':          Icons.card_giftcard_rounded,
  'help':          Icons.help_outline_rounded,
  'cancel_doc':    Icons.cancel_presentation_rounded,
  'hourglass':     Icons.hourglass_bottom_rounded,
  'block':         Icons.block_rounded,
  'wallet':        Icons.account_balance_wallet_rounded,
  'warning':       Icons.warning_amber_rounded,
  'lock':          Icons.lock_outline_rounded,
  'notifications': Icons.notifications_none_rounded,
  'info':          Icons.info_outline_rounded,
  'delete':        Icons.delete_outline_rounded,
  'edit':          Icons.edit_rounded,
};

// ── Screen ────────────────────────────────────────────────────────────────────

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({
    super.key,
    required this.accountType,
    required this.collectionName,
  });

  final String accountType;
  final String collectionName;

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  static const Color _goOutsBlue    = Color(0xFF0392CA);
  static const Color _textPrimary   = Color(0xFF1C1C1C);
  static const Color _textSecondary = Color(0xFF6B7280);
  static const Color _softBorder    = Color(0xFFE8EEF3);
  static const Color _softBlueTint  = Color(0xFFF4FAFD);

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _firstNameController    = TextEditingController();
  final TextEditingController _surnameController      = TextEditingController();
  final TextEditingController _emailController        = TextEditingController();
  final TextEditingController _mobileNumberController = TextEditingController();
  final TextEditingController _referralCodeController = TextEditingController();
  final TextEditingController _customSubjectController = TextEditingController();
  final TextEditingController _messageController      = TextEditingController();

  bool _isLoading    = true;
  bool _isSubmitting = false;

  String     _selectedTopicValue = '';
  String     _selectedTopicLabel = '— Select a Topic —';
  String?    _selectedSubTopic;
  bool       _showCustomSubject = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentProfile();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _surnameController.dispose();
    _emailController.dispose();
    _mobileNumberController.dispose();
    _referralCodeController.dispose();
    _customSubjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentProfile() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      return;
    }

    try {
      final DocumentSnapshot<Map<String, dynamic>> snapshot =
          await FirebaseFirestore.instance
              .collection(widget.collectionName)
              .doc(user.uid)
              .get();

      final Map<String, dynamic> data = snapshot.data() ?? {};

      _firstNameController.text    = (data['firstName']   ?? '').toString().trim();
      _surnameController.text      = (data['surname']     ?? '').toString().trim();
      _emailController.text        = (data['email']       ?? '').toString().trim();
      _mobileNumberController.text = (data['mobileNumber'] ?? user.phoneNumber ?? '').toString().trim();
      _referralCodeController.text = (data['ownReferralCode'] ?? data['referralCode'] ?? '')
          .toString().trim().toUpperCase();
    } catch (_) {}

    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  InputDecoration _inputDecoration({
    required String label,
    String? hint,
    bool alignLabelWithHint = false,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      alignLabelWithHint: alignLabelWithHint,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _softBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _softBorder),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        borderSide: BorderSide(color: _goOutsBlue, width: 1.4),
      ),
      errorBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        borderSide: BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        borderSide: BorderSide(color: Colors.red, width: 1.4),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    );
  }

  String? _requiredValidator(String? value, String label) {
    if (value == null || value.trim().isEmpty) return '$label is required';
    return null;
  }

  // ── Topic dropdown ────────────────────────────────────────────────────────
  // Same control as goouts_app's Contact Support screen: a real dropdown,
  // not a tile grid.
  Widget _topicDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F6FA),
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedTopicValue,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey),
          style: const TextStyle(fontSize: 14, color: _textPrimary),
          onChanged: (v) {
            if (v == null) return;
            final t = _topics.firstWhere((t) => t['value'] == v);
            setState(() {
              _selectedTopicValue = v;
              _selectedTopicLabel = t['label']!;
              _selectedSubTopic   = null;
              _showCustomSubject  = v == 'other';
              _customSubjectController.clear();
            });
          },
          items: _topics
              .map((t) => DropdownMenuItem(
                    value: t['value'],
                    child: Text(t['label']!,
                        style: const TextStyle(fontSize: 14, color: _textPrimary)),
                  ))
              .toList(),
        ),
      ),
    );
  }

  // ── Sub-topic tile — icon + description, matching goouts_app ───────────────
  Widget _subTopicTile(Map<String, String> sub) {
    final bool isSelected = _selectedSubTopic == sub['label'];
    // Once one is picked, collapse the rest — same as goouts_app.
    if (_selectedSubTopic != null && !isSelected) return const SizedBox.shrink();
    final bool isSomethingElse = sub['label'] == 'Something Else';
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedSubTopic  = sub['label'];
          _showCustomSubject = isSomethingElse;
          if (!isSomethingElse) _customSubjectController.clear();
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? _goOutsBlue.withValues(alpha: 0.06) : const Color(0xFFF8FAFB),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? _goOutsBlue : Colors.grey[200]!,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: isSelected ? _goOutsBlue.withValues(alpha: 0.15) : Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(
              _topicIconMap[sub['icon']] ?? Icons.help_outline_rounded,
              color: isSelected ? _goOutsBlue : Colors.grey[500],
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(sub['label']!, style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? _goOutsBlue : _textPrimary)),
              Text(sub['desc']!, style: const TextStyle(
                fontSize: 12, color: _textSecondary)),
            ],
          )),
          if (isSelected) ...[
            const Icon(Icons.check_circle_rounded, color: _goOutsBlue, size: 20),
            GestureDetector(
              onTap: () => setState(() {
                _selectedSubTopic = null;
                _showCustomSubject = false;
                _customSubjectController.clear();
              }),
              child: const Padding(
                padding: EdgeInsets.only(left: 10),
                child: Text('Change', style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600, color: _goOutsBlue)),
              ),
            ),
          ],
        ]),
      ),
    );
  }

  Future<void> _submitForm() async {
    FocusScope.of(context).unfocus();

    if (_selectedTopicValue.isEmpty) {
      GoOutsSheet.warning(context, title: 'Required', message: 'Please select a topic.');
      return;
    }

    final bool hasSubTopics = _subTopics.containsKey(_selectedTopicValue);
    if (hasSubTopics && _selectedSubTopic == null) {
      GoOutsSheet.warning(context, title: 'Required', message: 'Please select a sub-topic.');
      return;
    }

    if (_showCustomSubject && _customSubjectController.text.trim().isEmpty) {
      GoOutsSheet.warning(context, title: 'Required', message: 'Please describe your issue.');
      return;
    }

    if (!(_formKey.currentState?.validate() ?? false)) return;

    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isSubmitting = true);

    // Build subject string
    final String subjectLabel = _showCustomSubject
        ? _customSubjectController.text.trim()
        : (_selectedSubTopic ?? _selectedTopicLabel);

    final String fullSubject = _selectedTopicValue == 'other'
        ? subjectLabel
        : '$_selectedTopicLabel — $subjectLabel';

    try {
      final String driverName =
          '${_firstNameController.text.trim()} ${_surnameController.text.trim()}'.trim();
      final String messageText = _messageController.text.trim();

      final docRef = await FirebaseFirestore.instance
          .collection('support_requests')
          .add({
        'uid':              user.uid,
        'accountType':      widget.accountType,
        'sourceCollection': widget.collectionName,
        'firstName':        _firstNameController.text.trim(),
        'surname':          _surnameController.text.trim(),
        'email':            _emailController.text.trim(),
        'mobileNumber':     _mobileNumberController.text.trim(),
        'referralCode':     _referralCodeController.text.trim().toUpperCase(),
        'category':         _selectedTopicValue,
        'categoryLabel':    _selectedTopicLabel,
        'subTopic':         _selectedSubTopic ?? '',
        'subject':          fullSubject,
        'message':          messageText,
        'status':           'new',
        'lastMessage':      messageText,
        'lastMessageAt':    FieldValue.serverTimestamp(),
        'lastMessageBy':    'driver',
        'unreadByAdmin':    true,
        'unreadByDriver':   false,
        'createdAt':        FieldValue.serverTimestamp(),
      });

      // Save ticket number back into document
      await docRef.update({'ticketNumber': docRef.id});

      // Save original message as first entry in messages subcollection
      await docRef.collection('messages').add({
        'sender':     'driver',
        'senderName': driverName,
        'text':       messageText,
        'imageUrl':   '',
        'isRead':     false,
        'createdAt':  FieldValue.serverTimestamp(),
      });

      final String shortTicket = 'SR-${docRef.id.substring(0, 8).toUpperCase()}';

      if (!mounted) return;

      // Show success bottom sheet.
      // IMPORTANT: use the builder's own context (sheetCtx) for Navigator.pop —
      // using the outer context can pop the wrong route and lose the return value.
      final bool openedTicket = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetCtx) => SafeArea(
          top: false,
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  clipBehavior: Clip.antiAlias,
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2)),
                ),
                Container(
                  width: 64, height: 64,
                  decoration: const BoxDecoration(
                      color: Color(0xFFDCFCE7), shape: BoxShape.circle),
                  child: const Icon(Icons.check_circle_rounded,
                      color: Color(0xFF16A34A), size: 36),
                ),
                const SizedBox(height: 16),
                const Text('Ticket Submitted!',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
                      color: Color(0xFF0D1B3E))),
                const SizedBox(height: 8),
                Text(
                  'Thanks for contacting us. We\'re looking into this and will be in touch shortly.\n\nTicket: $shortTicket',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.grey[500], height: 1.5),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity, height: 52,
                  child: ElevatedButton.icon(
                    // Pop the sheet with true — use sheetCtx, NOT outer context
                    onPressed: () => Navigator.pop(sheetCtx, true),
                    icon: const Icon(Icons.chat_rounded, color: Colors.white, size: 18),
                    label: const Text('Open My Ticket',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                          color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _goOutsBlue,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14))),
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => Navigator.pop(sheetCtx, false),
                  child: Text('Back to Help',
                    style: TextStyle(fontSize: 14, color: Colors.grey[500])),
                ),
              ],
            ),
          ),
        ),
      ) ?? false;

      if (!mounted) return;

      if (openedTicket) {
        // Push chat screen and AWAIT it — form resets when user presses back
        await Navigator.push(context, MaterialPageRoute(
          builder: (_) => SupportTicketChatScreen(
            ticketId:         docRef.id,
            subject:          fullSubject,
            ticketNumber:     shortTicket,
            driverName:       driverName,
            sourceCollection: widget.collectionName,
          ),
        ));
        if (!mounted) return;
      }

      // Reset form — either user chose "Back to Help" or returned from chat
      _messageController.clear();
      _customSubjectController.clear();
      setState(() {
        _selectedTopicValue = '';
        _selectedTopicLabel = '— Select a Topic —';
        _selectedSubTopic   = null;
        _showCustomSubject  = false;
      });
    } catch (_) {
      if (!mounted) return;
      GoOutsSheet.error(context, title: 'Submit Failed', message: 'Failed to submit. Please try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _textPrimary,
        elevation: 0,
        centerTitle: true,
        title: const AutoSizeText('Help & Support',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        actions: [
          _MyTicketsButton(
            collectionName: widget.collectionName,
            getFullName: () {
              final firstName = _firstNameController.text.trim();
              final surname   = _surnameController.text.trim();
              return [firstName, surname].where((s) => s.isNotEmpty).join(' ');
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _goOutsBlue))
          : SafeArea(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [

                    // ── My Tickets banner ───────────────────────────────────
                    GestureDetector(
                      onTap: () {
                        final firstName = _firstNameController.text.trim();
                        final surname   = _surnameController.text.trim();
                        final fullName  = [firstName, surname]
                            .where((s) => s.isNotEmpty).join(' ');
                        Navigator.push(context, MaterialPageRoute(
                          builder: (_) => MyTicketsScreen(
                            sourceCollection: widget.collectionName,
                            driverName: fullName.isNotEmpty ? fullName : 'Driver',
                          ),
                        ));
                      },
                      child: Container(
                        clipBehavior: Clip.antiAlias,
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: _goOutsBlue,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(children: [
                          const Icon(Icons.confirmation_number_rounded,
                              color: Colors.white, size: 22),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text('View My Support Tickets',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white)),
                              SizedBox(height: 2),
                              Text('Already submitted a request? Track and reply here.',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white70,
                                      height: 1.3)),
                            ]),
                          ),
                          const Icon(Icons.chevron_right_rounded,
                              color: Colors.white70, size: 22),
                        ]),
                      ),
                    ),

                    // ── Info banner ─────────────────────────────────────────
                    Container(
                      clipBehavior: Clip.antiAlias,
                      margin: const EdgeInsets.only(bottom: 20),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                          color: _softBlueTint,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _softBorder)),
                      child: Text(
                        widget.accountType == 'business'
                            ? 'Send a support message for your business account.'
                            : 'Send a support message for your driver account.',
                        style: const TextStyle(
                            fontSize: 13,
                            height: 1.45,
                            color: _textSecondary,
                            fontWeight: FontWeight.w600)),
                    ),

                    // ── Topic dropdown ──────────────────────────────────────
                    _SectionCard(
                      title: 'What is your issue about?',
                      subtitle: 'Select the topic that best fits your problem.',
                      children: [
                        _topicDropdown(),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── Sub-topic tiles (appears after topic selected) ───────
                    if (_selectedTopicValue.isNotEmpty &&
                        _subTopics.containsKey(_selectedTopicValue)) ...[
                      _SectionCard(
                        title: 'What is the specific issue?',
                        subtitle: '',
                        children: [
                          ..._subTopics[_selectedTopicValue]!
                              .map((t) => _subTopicTile(t)),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ── Custom subject (Something else) ─────────────────────
                    if (_showCustomSubject) ...[
                      _SectionCard(
                        title: 'Describe your issue',
                        subtitle: '',
                        children: [
                          TextFormField(
                            controller: _customSubjectController,
                            decoration:
                                _inputDecoration(label: 'Brief description'),
                            validator: (v) =>
                                (_showCustomSubject &&
                                        (v == null || v.trim().isEmpty))
                                    ? 'Please describe your issue'
                                    : null,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ── Message + Submit ─────────────────────────────────────
                    if (_selectedTopicValue.isNotEmpty &&
                        (_selectedSubTopic != null ||
                            _selectedTopicValue == 'other')) ...[
                      _SectionCard(
                        title: 'Your Message',
                        subtitle: 'Provide as much detail as possible.',
                        children: [
                          TextFormField(
                            controller: _messageController,
                            minLines: 5,
                            maxLines: 8,
                            decoration: _inputDecoration(
                              label: 'Describe your issue in detail',
                              alignLabelWithHint: true,
                            ),
                            validator: (v) =>
                                _requiredValidator(v, 'Message'),
                          ),
                          const SizedBox(height: 18),
                          SizedBox(
                            height: 54,
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed:
                                  _isSubmitting ? null : _submitForm,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _goOutsBlue,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(14))),
                              child: _isSubmitting
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2.2,
                                          color: Colors.white))
                                  : const AutoSizeText('Submit',
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}

// ── My Tickets AppBar button with unread badge ───────────────────────────────
class _MyTicketsButton extends StatelessWidget {
  final String collectionName;
  final String Function() getFullName;

  const _MyTicketsButton({
    required this.collectionName,
    required this.getFullName,
  });

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('support_requests')
          .where('uid', isEqualTo: uid)
          .where('unreadByDriver', isEqualTo: true)
          .snapshots(),
      builder: (context, snap) {
        final unreadCount = snap.data?.docs.length ?? 0;

        return GestureDetector(
          onTap: () {
            final fullName = getFullName();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MyTicketsScreen(
                  sourceCollection: collectionName,
                  driverName: fullName.isNotEmpty ? fullName : 'Driver',
                ),
              ),
            );
          },
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                clipBehavior: Clip.antiAlias,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0392CA).withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(0xFF0392CA).withValues(alpha: 0.25)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: const [
                  Icon(Icons.confirmation_number_rounded, size: 16, color: Color(0xFF0392CA)),
                  SizedBox(width: 5),
                  Text(
                    'My Tickets',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0392CA),
                    ),
                  ),
                ]),
              ),
              // Red badge
              if (unreadCount > 0)
                Positioned(
                  top: -5,
                  right: -5,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                      color: Color(0xFFDC2626),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      unreadCount > 9 ? '9+' : '$unreadCount',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ── Reusable section card ─────────────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8EEF3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AutoSizeText(title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800,
              color: Color(0xFF1C1C1C))),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 4),
            AutoSizeText(subtitle,
              style: const TextStyle(fontSize: 12, height: 1.45,
                color: Color(0xFF6B7280), fontWeight: FontWeight.w500)),
          ],
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}
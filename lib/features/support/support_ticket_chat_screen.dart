import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class SupportTicketChatScreen extends StatefulWidget {
  final String ticketId;
  final String subject;
  final String ticketNumber;
  final String driverName;
  final String sourceCollection;

  const SupportTicketChatScreen({
    super.key,
    required this.ticketId,
    required this.subject,
    required this.ticketNumber,
    required this.driverName,
    required this.sourceCollection,
  });

  @override
  State<SupportTicketChatScreen> createState() =>
      _SupportTicketChatScreenState();
}

class _SupportTicketChatScreenState
    extends State<SupportTicketChatScreen> {
  // ── colours ──────────────────────────────────────────────────────────────────
  static const Color _blue    = Color(0xFF0392CA);
  static const Color _bg      = Color(0xFFF2F3F7);
  static const Color _dark    = Color(0xFF1C1C1C);

  // ── controllers ──────────────────────────────────────────────────────────────
  final _msgCtrl    = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _picker     = ImagePicker();

  // ── state ────────────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _msgs       = [];
  bool                       _loading    = true;
  String?                    _error;
  String                     _status     = 'open';
  bool                       _sending    = false;
  bool                       _uploading  = false;

  // ── subscriptions ─────────────────────────────────────────────────────────────
  StreamSubscription<QuerySnapshot>?    _msgSub;
  StreamSubscription<DocumentSnapshot>? _ticketSub;

  // ── Firestore refs ────────────────────────────────────────────────────────────
  CollectionReference get _msgsRef => FirebaseFirestore.instance
      .collection('support_requests')
      .doc(widget.ticketId)
      .collection('messages');

  DocumentReference get _ticketRef => FirebaseFirestore.instance
      .collection('support_requests')
      .doc(widget.ticketId);

  @override
  void initState() {
    super.initState();

    // Listen to messages — no orderBy so pending timestamps are included.
    // We sort in Dart instead.
    _msgSub = _msgsRef.snapshots().listen(
      (snap) {
        if (!mounted) return;
        final sorted = snap.docs.toList()
          ..sort((a, b) {
            final aTs = (a.data() as Map)['createdAt'] as Timestamp?;
            final bTs = (b.data() as Map)['createdAt'] as Timestamp?;
            final aMs = aTs?.millisecondsSinceEpoch ?? 0;
            final bMs = bTs?.millisecondsSinceEpoch ?? 0;
            return aMs.compareTo(bMs);
          });
        setState(() {
          _msgs    = sorted.map((d) => Map<String, dynamic>.from(d.data() as Map)).toList();
          _loading = false;
          _error   = null;
        });
        _scrollToBottom();
      },
      onError: (e) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error   = e.toString();
        });
      },
    );

    // Listen to ticket status
    _ticketSub = _ticketRef.snapshots().listen((snap) {
      if (!mounted) return;
      final data   = snap.data() as Map<String, dynamic>? ?? {};
      final status = (data['status'] ?? 'open').toString();
      if (_status != status) setState(() => _status = status);
    });

    _markRead();
  }

  @override
  void dispose() {
    _msgSub?.cancel();
    _ticketSub?.cancel();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _markRead() async {
    try {
      final snap = await _msgsRef
          .where('sender', isEqualTo: 'admin')
          .where('isRead', isEqualTo: false)
          .get();
      final batch = FirebaseFirestore.instance.batch();
      for (final d in snap.docs) {
        batch.update(d.reference, {'isRead': true});
      }
      await batch.commit();
      await _ticketRef.update({'unreadByDriver': false});
    } catch (_) {}
  }

  Future<void> _send({String text = '', String imageUrl = ''}) async {
    if (text.trim().isEmpty && imageUrl.isEmpty) return;
    if (_isClosed) return;
    setState(() => _sending = true);
    try {
      await _msgsRef.add({
        'sender':     'driver',
        'senderType': 'driver',
        'senderName': widget.driverName,
        'text':       text.trim(),
        'imageUrl':   imageUrl,
        'isRead':     false,
        'isSystemMessage': false,
        'createdAt':  FieldValue.serverTimestamp(),
      });
      await _ticketRef.update({
        'lastMessage':   text.trim().isEmpty ? '📎 Image attached' : text.trim(),
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastMessageBy': 'driver',
        'unreadByAdmin': true,
        'status':        'in_progress',
        'updatedAt':     FieldValue.serverTimestamp(),
      });
      _msgCtrl.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), behavior: SnackBarBehavior.floating),
        );
      }
    }
    if (mounted) setState(() => _sending = false);
  }

  Future<void> _pickImage() async {
    final src = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.camera_alt_rounded, color: _blue),
            title: const Text('Camera'),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_rounded, color: _blue),
            title: const Text('Gallery'),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (src == null || !mounted) return;
    final picked = await _picker.pickImage(source: src, imageQuality: 70, maxWidth: 1200);
    if (picked == null || !mounted) return;
    setState(() => _uploading = true);
    try {
      final ref = FirebaseStorage.instance
          .ref('support_tickets/${widget.ticketId}/${DateTime.now().millisecondsSinceEpoch}.jpg');
      await ref.putFile(File(picked.path));
      final url = await ref.getDownloadURL();
      await _send(imageUrl: url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'), behavior: SnackBarBehavior.floating),
        );
      }
    }
    if (mounted) setState(() => _uploading = false);
  }

  Future<void> _closeTicket() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Close Ticket'),
        content: const Text('Mark this issue as resolved and close the ticket?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _blue, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Close Ticket'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _msgsRef.add({
        'sender':          'driver',
        'senderType':      'driver',
        'senderName':      widget.driverName,
        'text':            '✅ Driver marked this issue as resolved.',
        'imageUrl':        '',
        'isRead':          false,
        'isSystemMessage': true,
        'createdAt':       FieldValue.serverTimestamp(),
      });
      await _ticketRef.update({
        'status':        'resolved',
        'resolvedAt':    FieldValue.serverTimestamp(),
        'resolvedBy':    'driver',
        'unreadByAdmin': true,
        'updatedAt':     FieldValue.serverTimestamp(),
      });
      if (mounted) setState(() => _status = 'resolved');
      // Short delay then show rating sheet
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) await _showRatingSheet();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  Future<void> _showRatingSheet() async {
    int    stars   = 0;
    String comment = '';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        final bottom = MediaQuery.of(sheetCtx).viewInsets.bottom;
        return StatefulBuilder(
          builder: (_, setSS) => Container(
            margin: const EdgeInsets.all(12),
            padding: EdgeInsets.fromLTRB(20, 24, 20, bottom + 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // handle
              Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),

              // icon
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  color: _blue.withOpacity(0.10), shape: BoxShape.circle),
                child: const Icon(Icons.support_agent_rounded, size: 32, color: _blue)),
              const SizedBox(height: 14),

              const Text('Rate Your Support Experience',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              const Text('How satisfied were you with GoOuts Support?',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
              const SizedBox(height: 22),

              // stars
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                for (int i = 1; i <= 5; i++)
                  GestureDetector(
                    onTap: () => setSS(() => stars = i),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(
                        i <= stars ? Icons.star_rounded : Icons.star_outline_rounded,
                        size: 42,
                        color: i <= stars ? const Color(0xFFF59E0B) : const Color(0xFFCBD5E1)),
                    ),
                  ),
              ]),
              const SizedBox(height: 6),
              Text(
                stars == 0 ? 'Tap to rate'
                  : stars == 1 ? 'Poor'
                  : stars == 2 ? 'Fair'
                  : stars == 3 ? 'Good'
                  : stars == 4 ? 'Very Good'
                  : 'Excellent!',
                style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700,
                  color: stars == 0 ? const Color(0xFF94A3B8)
                    : stars >= 4 ? const Color(0xFF16A34A)
                    : const Color(0xFFF59E0B)),
              ),
              const SizedBox(height: 18),

              // comment field
              TextField(
                maxLines: 3, minLines: 2,
                onChanged: (v) => comment = v,
                decoration: InputDecoration(
                  hintText: 'Leave a comment (optional)...',
                  hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                  filled: true, fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.all(14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE8EEF3))),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE8EEF3))),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _blue, width: 1.4)),
                ),
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),

              // submit
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: stars == 0 ? null : () async {
                    Navigator.pop(sheetCtx);
                    await _submitRating(stars: stars, comment: comment.trim());
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _blue,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFFCBD5E1),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
                  child: const Text('Submit Rating',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(sheetCtx),
                child: const Text('Skip', style: TextStyle(color: Color(0xFF94A3B8))),
              ),
            ]),
          ),
        );
      },
    );
  }

  Future<void> _submitRating({required int stars, required String comment}) async {
    final label = stars == 1 ? 'Poor'
                : stars == 2 ? 'Fair'
                : stars == 3 ? 'Good'
                : stars == 4 ? 'Very Good'
                : 'Excellent';
    try {
      await _ticketRef.update({
        'rating':        stars,
        'ratingComment': comment,
        'ratingLabel':   label,
        'ratedAt':       FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thanks for your feedback! ⭐'),
            backgroundColor: Color(0xFF16A34A),
            behavior: SnackBarBehavior.floating));
      }
    } catch (_) {}
  }

  bool get _isClosed => _status == 'closed' || _status == 'resolved';

  String _fmtTime(Timestamp? ts) {
    if (ts == null) return '';
    final d = ts.toDate().toLocal();
    final now = DateTime.now();
    final hm  = '${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';
    if (d.year == now.year && d.month == now.month && d.day == now.day) return hm;
    return '${d.day}/${d.month} $hm';
  }

  // ── Status badge colour ───────────────────────────────────────────────────────
  Color _statusColor() {
    switch (_status) {
      case 'new':            return _blue;
      case 'in_progress':    return const Color(0xFFD97706);
      case 'need_more_info': return const Color(0xFF7C3AED);
      case 'waiting_driver': return const Color(0xFF0891B2);
      case 'resolved':       return const Color(0xFF16A34A);
      case 'closed':         return const Color(0xFF64748B);
      default:               return _blue;
    }
  }

  String _statusLabel() {
    switch (_status) {
      case 'new':            return 'New';
      case 'in_progress':    return 'In Progress';
      case 'need_more_info': return 'Need Info';
      case 'waiting_driver': return 'Action Needed';
      case 'resolved':       return 'Resolved';
      case 'closed':         return 'Closed';
      default:               return _status;
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _dark,
        elevation: 0.5,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.subject,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
          Text(widget.ticketNumber,
            style: const TextStyle(fontSize: 11, color: _blue, fontWeight: FontWeight.w600)),
        ]),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _statusColor().withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(_statusLabel(),
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _statusColor())),
          ),
        ],
      ),
      body: Column(children: [
        // ── messages ────────────────────────────────────────────────────────────
        Expanded(child: _buildMessageArea()),

        // ── closed banner ───────────────────────────────────────────────────────
        if (_isClosed)
          Container(
            width: double.infinity,
            color: const Color(0xFFDCFCE7),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: const Row(children: [
              Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 18),
              SizedBox(width: 8),
              Expanded(child: Text(
                'This ticket is closed. Open a new request if you need help.',
                style: TextStyle(fontSize: 12, color: Color(0xFF16A34A), fontWeight: FontWeight.w600))),
            ]),
          )

        // ── reply bar ───────────────────────────────────────────────────────────
        else
          _buildReplyBar(),
      ]),
    );
  }

  Widget _buildMessageArea() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _blue));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline, color: Color(0xFFCC0000), size: 40),
            const SizedBox(height: 12),
            const Text('Could not load messages.',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(fontSize: 12, color: Colors.black54),
              textAlign: TextAlign.center),
          ]),
        ),
      );
    }
    if (_msgs.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.chat_bubble_outline_rounded, size: 56, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text('No messages yet.',
            style: TextStyle(color: Colors.grey[500], fontSize: 15, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          Text('Send a message below to start.',
            style: TextStyle(color: Colors.grey[400], fontSize: 13)),
        ]),
      );
    }
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
      itemCount: _msgs.length,
      itemBuilder: (_, i) => _buildBubble(_msgs[i]),
    );
  }

  Widget _buildBubble(Map<String, dynamic> data) {
    final sender    = (data['sender'] ?? '').toString();
    final isDriver  = sender == 'driver';
    final isSystem  = data['isSystemMessage'] == true;
    final text      = (data['text'] ?? '').toString();
    final imageUrl  = (data['imageUrl'] ?? '').toString();
    final ts        = data['createdAt'] as Timestamp?;

    // System messages — centred green pill
    if (isSystem) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFDCFCE7),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(text,
            style: const TextStyle(fontSize: 12, color: Color(0xFF16A34A), fontWeight: FontWeight.w600)),
        ),
      );
    }

    return Align(
      alignment: isDriver ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.76),
        margin: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: isDriver ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // sender label
            Padding(
              padding: const EdgeInsets.only(bottom: 4, left: 4, right: 4),
              child: Text(
                isDriver ? 'You' : 'GoOuts Support',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDriver ? _blue : const Color(0xFF64748B)),
              ),
            ),

            // bubble
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDriver ? _blue : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.only(
                  topLeft:     const Radius.circular(16),
                  topRight:    const Radius.circular(16),
                  bottomLeft:  Radius.circular(isDriver ? 16 : 4),
                  bottomRight: Radius.circular(isDriver ? 4 : 16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 2)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (text.isNotEmpty)
                    Text(text,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDriver ? Colors.white : _dark,
                        height: 1.4)),
                  if (imageUrl.isNotEmpty) ...[
                    if (text.isNotEmpty) const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(imageUrl,
                        width: 200, fit: BoxFit.cover,
                        loadingBuilder: (_, child, p) =>
                            p == null ? child : const SizedBox(height: 100,
                              child: Center(child: CircularProgressIndicator(color: _blue, strokeWidth: 2))),
                        errorBuilder: (_, __, ___) => Container(
                          width: 200, height: 80, color: const Color(0xFFE2E8F0),
                          child: const Center(child: Icon(Icons.broken_image_rounded, color: Color(0xFF94A3B8)))),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // timestamp
            Padding(
              padding: const EdgeInsets.only(top: 3, left: 4, right: 4),
              child: Text(_fmtTime(ts),
                style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReplyBar() {
    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE8EEF3))),
        ),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // text row
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            // image button
            GestureDetector(
              onTap: _uploading ? null : _pickImage,
              child: Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: _blue, borderRadius: BorderRadius.circular(12)),
                child: _uploading
                    ? const Padding(padding: EdgeInsets.all(10),
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.attach_file_rounded, size: 20, color: Colors.white),
              ),
            ),
            const SizedBox(width: 8),

            // text field
            Expanded(
              child: TextField(
                controller: _msgCtrl,
                maxLines: 4,
                minLines: 1,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE8EEF3))),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE8EEF3))),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _blue, width: 1.4)),
                ),
                style: const TextStyle(fontSize: 14),
              ),
            ),
            const SizedBox(width: 8),

            // send button
            GestureDetector(
              onTap: _sending ? null : () => _send(text: _msgCtrl.text),
              child: Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: _blue, borderRadius: BorderRadius.circular(12)),
                child: _sending
                    ? const Padding(padding: EdgeInsets.all(10),
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send_rounded, size: 20, color: Colors.white),
              ),
            ),
          ]),
          const SizedBox(height: 10),

          // close ticket button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _closeTicket,
              icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
              label: const Text('Issue Resolved — Close Ticket',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF16A34A),
                side: const BorderSide(color: Color(0xFF16A34A)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 10)),
            ),
          ),
        ]),
      ),
    );
  }
}

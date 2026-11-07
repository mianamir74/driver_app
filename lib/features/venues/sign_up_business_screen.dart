// ─────────────────────────────────────────────────────────────────────────────
//  Sign Up a Business. Added 25 October 2026 (GoOuts Lead version 1.1).
//
//  A driver fills this in at the counter with the owner. It calls the
//  submitVenueFromApp Cloud Function (venue_bonus.js), which checks every
//  field again, refuses a venue someone already signed up, and puts it in the
//  admin panel's Partner Applications queue with the driver as introducer.
//  Field names and choices match the website form (business.html) so the
//  same approve button works for both.
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

const Color _blue = Color(0xFF0392CA);
const Color _ink = Color(0xFF1C1C1C);
const Color _muted = Color(0xFF6B7280);
const Color _line = Color(0xFFDFE5EC);

const List<String> _types = [
  'Restaurant',
  'Takeaway / Fast Food',
  'Cafe / Coffee Shop',
  'Pub / Bar',
  'Dessert / Bakery',
  'Grocery / Convenience',
  'Club / Music / Comedy venue',
  'Other',
];
const Set<String> _alwaysFood = {
  'Restaurant',
  'Takeaway / Fast Food',
  'Cafe / Coffee Shop',
  'Dessert / Bakery',
  'Grocery / Convenience',
};
const List<String> _cuisines = [
  'Pizza', 'Indian', 'Chinese', 'Burgers', 'Chicken', 'Kebab', 'Turkish',
  'Pakistani', 'Bangladeshi', 'Lebanese', 'Mediterranean', 'Italian', 'Thai',
  'Japanese', 'Sushi', 'Korean BBQ', 'Vietnamese', 'Mexican', 'American',
  'British', 'Fish & Chips', 'Greek', 'Caribbean', 'Nigerian', 'Healthy',
  'Vegan', 'Breakfast', 'Sandwiches', 'Coffee & Cafe', 'Bakery', 'Desserts',
  'Ice Cream', 'Bubble Tea', 'Groceries',
];
const Map<String, String> _channels = {
  'venue': 'In the venue only',
  'online': 'Online orders only',
  'both': 'Both',
};
const List<String> _fulfilment = [
  'Food delivery with GoOuts drivers',
  'Food delivery with our own drivers',
  'Collection orders',
];

class SignUpBusinessScreen extends StatefulWidget {
  const SignUpBusinessScreen({super.key});

  @override
  State<SignUpBusinessScreen> createState() => _SignUpBusinessScreenState();
}

class _SignUpBusinessScreenState extends State<SignUpBusinessScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _town = TextEditingController(text: 'London');
  final _postcode = TextEditingController();
  final _owner = TextEditingController();
  final _role = TextEditingController(text: 'Owner');
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _cashback = TextEditingController(text: '5');
  final _hours = TextEditingController();
  final _notes = TextEditingController();

  String? _type;
  String _channel = 'both';
  bool _servesFood = true;
  final Set<String> _picked = {};
  final Set<String> _fulfil = {'Food delivery with GoOuts drivers'};
  bool _feeOk = false;
  bool _ownerAgreed = false;
  File? _photo;
  bool _busy = false;

  bool get _food => _type != null && (_alwaysFood.contains(_type) || _servesFood);
  bool get _inVenue => _channel != 'online';
  bool get _online => _channel != 'venue';
  bool get _selfTerms => _type != null && _type != 'Restaurant' && _inVenue;

  @override
  void dispose() {
    for (final c in [
      _name, _address, _town, _postcode, _owner, _role, _phone, _email,
      _cashback, _hours, _notes,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _takePhoto() async {
    try {
      final x = await ImagePicker().pickImage(
          source: ImageSource.camera, maxWidth: 1600, imageQuality: 75);
      if (x != null && mounted) setState(() => _photo = File(x.path));
    } catch (_) {
      _toast('Could not open the camera.');
    }
  }

  Future<String> _uploadPhoto(String uid) async {
    if (_photo == null) return '';
    final ref = FirebaseStorage.instance.ref(
        'merchant_applications/$uid/${DateTime.now().millisecondsSinceEpoch}.jpg');
    await ref.putFile(_photo!, SettableMetadata(contentType: 'image/jpeg'));
    return ref.getDownloadURL();
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (_type == null) {
      _toast('Please choose the type of business.');
      return;
    }
    if (!(_form.currentState?.validate() ?? false)) {
      _toast('Please check the fields marked in red.');
      return;
    }
    if (_food && _picked.isEmpty) {
      _toast('Please choose at least one cuisine.');
      return;
    }
    if (_online && !_food) {
      _toast('Online orders are only for businesses that serve food.');
      return;
    }
    if (_online && _fulfil.isEmpty) {
      _toast('Please choose how online orders reach customers.');
      return;
    }
    if (_selfTerms && !_feeOk) {
      _toast('Please confirm the owner understands the 5% GoOuts fee.');
      return;
    }
    if (!_ownerAgreed) {
      _toast('Please confirm the owner agreed to join GoOuts.');
      return;
    }
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      _toast('Please log in again.');
      return;
    }

    setState(() => _busy = true);
    try {
      String photoUrl = '';
      try {
        photoUrl = await _uploadPhoto(uid);
      } catch (_) {
        // The photo is optional. Never lose the sign up over it.
      }
      await FirebaseFunctions.instanceFor(region: 'europe-west1')
          .httpsCallable('submitVenueFromApp')
          .call(<String, dynamic>{
        'venueName': _name.text.trim(),
        'businessType': _type,
        'salesChannel': _channel,
        'servesFood': _food,
        'cuisines': _food ? _picked.toList() : <String>[],
        'onlineFulfilment': _online ? _fulfil.toList() : <String>[],
        'address': _address.text.trim(),
        'town': _town.text.trim(),
        'postcode': _postcode.text.trim(),
        'contactName': _owner.text.trim(),
        'contactRole': _role.text.trim(),
        'phone': _phone.text.trim(),
        'email': _email.text.trim(),
        'cashbackPct': _selfTerms ? double.tryParse(_cashback.text.trim()) : null,
        'feeAcknowledged': _selfTerms && _feeOk,
        'openingHours': _hours.text.trim(),
        'notes': _notes.text.trim(),
        'photoUrl': photoUrl,
        'ownerAgreed': _ownerAgreed,
      });
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Business submitted'),
          content: Text(
              '${_name.text.trim()} is now with GoOuts for checking. You are '
              'credited as the introducer. Follow its progress in My '
              'Businesses.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('OK')),
          ],
        ),
      );
      if (mounted) Navigator.of(context).pop();
    } on FirebaseFunctionsException catch (e) {
      _toast(e.message ?? 'Could not submit. Please try again.');
    } catch (_) {
      _toast('Could not submit. Please check your signal and try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── UI helpers ──────────────────────────────────────────────────────────

  InputDecoration _dec(String label, {String? hint}) => InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _line)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _line)),
      );

  Widget _field(TextEditingController c, String label,
          {bool required = true,
          TextInputType? keyboard,
          String? hint,
          String? Function(String)? check,
          TextCapitalization caps = TextCapitalization.words,
          int maxLines = 1}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          controller: c,
          keyboardType: keyboard,
          textCapitalization: caps,
          maxLines: maxLines,
          decoration: _dec(required ? '$label *' : label, hint: hint),
          validator: (v) {
            final t = (v ?? '').trim();
            if (required && t.isEmpty) return 'Required';
            if (t.isNotEmpty && check != null) return check(t);
            return null;
          },
        ),
      );

  Widget _section(String title, [String? sub]) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w800, color: _ink)),
          if (sub != null) ...[
            const SizedBox(height: 2),
            Text(sub, style: const TextStyle(fontSize: 12.5, color: _muted)),
          ],
        ]),
      );

  Widget _chip(String label, bool on, VoidCallback tap) => FilterChip(
        label: Text(label),
        selected: on,
        onSelected: (_) => tap(),
        selectedColor: _blue,
        checkmarkColor: Colors.white,
        labelStyle: TextStyle(color: on ? Colors.white : _ink, fontSize: 13),
        backgroundColor: Colors.white,
        side: BorderSide(color: on ? _blue : _line),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        backgroundColor: _blue,
        foregroundColor: Colors.white,
        title: const Text('Sign Up a Business',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: const Color(0xFFE3F2FD),
                    borderRadius: BorderRadius.circular(12)),
                child: const Text(
                  'Fill this in with the owner or manager. You are credited '
                  'as the introducer: £25 once the business is live and has '
                  '3 genuine customer transactions, plus residual income. '
                  'T&Cs apply.',
                  style: TextStyle(fontSize: 12.5, height: 1.45, color: Color(0xFF0B4F75)),
                ),
              ),

              _section('The business'),
              _field(_name, 'Business name'),
              const Text('Type of business *',
                  style: TextStyle(fontSize: 13, color: _muted)),
              const SizedBox(height: 6),
              Wrap(spacing: 8, runSpacing: 6, children: [
                for (final t in _types)
                  _chip(t, _type == t, () => setState(() => _type = t)),
              ]),
              if (_type != null && !_alwaysFood.contains(_type)) ...[
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _servesFood,
                  activeThumbColor: _blue,
                  onChanged: (v) => setState(() => _servesFood = v),
                  title: const Text('They serve food'),
                ),
              ],
              const SizedBox(height: 12),
              const Text('How do customers buy? *',
                  style: TextStyle(fontSize: 13, color: _muted)),
              const SizedBox(height: 6),
              Wrap(spacing: 8, runSpacing: 6, children: [
                for (final e in _channels.entries)
                  _chip(e.value, _channel == e.key,
                      () => setState(() => _channel = e.key)),
              ]),
              if (_food) ...[
                _section('Cuisine', 'Choose at least one.'),
                Wrap(spacing: 8, runSpacing: 6, children: [
                  for (final c in _cuisines)
                    _chip(c, _picked.contains(c), () => setState(() {
                          _picked.contains(c) ? _picked.remove(c) : _picked.add(c);
                        })),
                ]),
              ],
              if (_online) ...[
                _section('Online orders', 'How will orders reach customers?'),
                for (final f in _fulfilment)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    activeColor: _blue,
                    value: _fulfil.contains(f),
                    onChanged: (v) => setState(() {
                      v == true ? _fulfil.add(f) : _fulfil.remove(f);
                    }),
                    title: Text(f),
                  ),
              ],

              _section('Address'),
              _field(_address, 'Street address'),
              _field(_town, 'Town or city'),
              _field(_postcode, 'Postcode',
                  caps: TextCapitalization.characters,
                  check: (t) => RegExp(
                              r'^[A-Za-z]{1,2}[0-9][0-9A-Za-z]?\s?[0-9][A-Za-z]{2}$')
                          .hasMatch(t)
                      ? null
                      : 'Enter a valid UK postcode'),

              _section('Owner or manager',
                  'Their GoOuts login is sent to this email.'),
              _field(_owner, 'Full name'),
              _field(_role, 'Role', hint: 'Owner, manager...'),
              _field(_phone, 'Mobile number',
                  keyboard: TextInputType.phone,
                  hint: '07700 900123',
                  check: (t) => RegExp(r'^(\+44|0044|0)?7\d{9}$')
                          .hasMatch(t.replaceAll(RegExp(r'[\s\-()]'), ''))
                      ? null
                      : 'Enter a valid UK mobile'),
              _field(_email, 'Email',
                  keyboard: TextInputType.emailAddress,
                  caps: TextCapitalization.none,
                  check: (t) => RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(t)
                      ? null
                      : 'Enter a valid email'),

              if (_selfTerms) ...[
                _section('Cashback deal',
                    'In the venue, the business chooses the cashback its '
                        'customers get (5% minimum). GoOuts charges a fixed 5%.'),
                _field(_cashback, 'Customer cashback %',
                    keyboard: const TextInputType.numberWithOptions(decimal: true),
                    check: (t) {
                  final v = double.tryParse(t);
                  if (v == null || v < 5 || v > 50) return 'Between 5 and 50';
                  return null;
                }),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  activeColor: _blue,
                  value: _feeOk,
                  onChanged: (v) => setState(() => _feeOk = v == true),
                  title: const Text(
                      'The owner understands GoOuts charges a fixed 5% fee on '
                      'in-venue sales.',
                      style: TextStyle(fontSize: 13.5)),
                ),
              ],
              if (_type == 'Restaurant' && _inVenue)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text(
                    'For restaurants, GoOuts agrees the cashback and commission '
                    'with the owner after checking.',
                    style: TextStyle(fontSize: 12.5, color: _muted),
                  ),
                ),

              _section('Extra details', 'Optional, but they help.'),
              _field(_hours, 'Opening hours',
                  required: false, hint: 'e.g. Mon to Sun 11am to 11pm'),
              _field(_notes, 'Notes for GoOuts',
                  required: false,
                  caps: TextCapitalization.sentences,
                  maxLines: 3),
              GestureDetector(
                onTap: _busy ? null : _takePhoto,
                child: Container(
                  height: 140,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFB8CBD9)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _photo == null
                      ? const Center(
                          child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.photo_camera_rounded,
                                    color: _muted, size: 30),
                                SizedBox(height: 6),
                                Text('Take a photo of the shop front',
                                    style: TextStyle(color: _muted)),
                              ]),
                        )
                      : Image.file(_photo!, fit: BoxFit.cover,
                          width: double.infinity),
                ),
              ),

              const SizedBox(height: 14),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                activeColor: _blue,
                value: _ownerAgreed,
                onChanged: (v) => setState(() => _ownerAgreed = v == true),
                title: const Text(
                    'The owner or manager agreed to join GoOuts and to be '
                    'contacted by GoOuts. *',
                    style: TextStyle(fontSize: 13.5)),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: _busy ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _busy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.4, color: Colors.white))
                      : const Text('Submit business',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

/// Reusable Early Access banner.
/// Shown on the role selection screen and referenced in Terms & Conditions.
///
/// Redesigned: replaces the previous grey paragraph block with a branded
/// header strip plus a short ticked benefit list. The old version was three
/// dense paragraphs of grey text sitting directly above the two role buttons,
/// which pushed them down the screen and buried the reason to sign up. This
/// version leads with what the applicant gets, and is roughly half the height.
class EarlyAccessBanner extends StatelessWidget {
  const EarlyAccessBanner({super.key});

  static const Color _goOutsBlue = Color(0xFF0392CA);
  static const Color _borderBlue = Color(0xFFCDE7F2);
  static const Color _headingInk = Color(0xFF0B3D52);
  static const Color _bodyInk = Color(0xFF3D5A66);

  /// [highlight] draws the line in GoOuts blue and semi-bold — used for the
  /// residual income point, which is the strongest reason to enrol early.
  Widget _benefit(String text, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(
              highlight ? Icons.trending_up_rounded : Icons.check_rounded,
              size: 15,
              color: _goOutsBlue,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                height: 1.35,
                fontWeight: highlight ? FontWeight.w700 : FontWeight.w400,
                color: highlight ? _goOutsBlue : _headingInk,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderBlue),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Header strip
          Container(
            width: double.infinity,
            color: _goOutsBlue,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: const Row(
              children: <Widget>[
                Icon(
                  Icons.rocket_launch_rounded,
                  size: 15,
                  color: Colors.white,
                ),
                SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'Early access · Pre-launch',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Body
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  "Not a live platform yet — you're securing your place early.",
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.45,
                    color: _bodyInk,
                  ),
                ),
                const SizedBox(height: 10),
                _benefit('Reserve your spot now'),
                _benefit('Invite friends, track invitees'),
                _benefit(
                  'Build residual income from every driver you refer',
                  highlight: true,
                ),
                _benefit('First to know when we launch'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

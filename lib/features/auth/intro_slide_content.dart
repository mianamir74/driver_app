import 'package:flutter/material.dart';

/// Intro slides rebuilt as real Flutter text + small illustrations.
/// Replaces the old full-screen PNG slides in assets/intro/ (about 760 KB)
/// with compressed illustrations in assets/intro_art/ (about 85 KB).
/// Text is now crisp on every screen size and can be edited here directly.

const Color kIntroBlue = Color(0xFF008FC9);
const Color kIntroLine = Color(0xFF1EB7EB);
const Color kIntroPill = Color(0xFF00A2C9);
const Color kIntroInk = Color(0xFF111111);
const String kIntroFont = 'Helvetica';

/// Residual income tiers shown on the Commission Structure slide.
/// Keep in line with the company rule: % of the profit GoOuts makes,
/// paid for up to 2 years.
class IntroCommissionTier {
  final String tier;
  final String referrals;
  final String percent;
  final String note;
  const IntroCommissionTier(this.tier, this.referrals, this.percent, this.note);
}

const List<IntroCommissionTier> kIntroCommissionTiers = [
  IntroCommissionTier('1', '1 to 5', '2%', 'Base commission\nfor new partners'),
  IntroCommissionTier('2', '6 to 10', '3%', 'Higher reward for\ngrowing network'),
  IntroCommissionTier('3', '11 to 50', '5%', 'Real game\nstarts'),
];

/// One body line. [highlight] (if set) is drawn in blue at the start.
class IntroLine {
  final String text;
  final String? highlight;
  const IntroLine(this.text, {this.highlight});
}

class IntroSlideData {
  final String titleTop;
  final String titleBottom;
  final String art;
  final List<IntroLine> above; // lines above the blue divider
  final List<IntroLine> below; // lines below the blue divider
  final bool isCommission;

  const IntroSlideData({
    required this.titleTop,
    required this.titleBottom,
    required this.art,
    this.above = const [],
    this.below = const [],
    this.isCommission = false,
  });
}

class IntroSlides {
  static const _p = 'assets/intro_art/';

  static const becomePartnerDriver = IntroSlideData(
    titleTop: 'BECOME',
    titleBottom: 'PARTNER',
    art: '${_p}become_partner_driver.webp',
    above: [IntroLine('Join GoOuts and earn money')],
    below: [IntroLine('by delivering orders in your area')],
  );

  static const becomePartnerBusiness = IntroSlideData(
    titleTop: 'BECOME',
    titleBottom: 'PARTNER',
    art: '${_p}become_partner_business.webp',
    above: [IntroLine('Join GoOuts and earn money')],
    below: [IntroLine('by signing up new delivery drivers')],
  );

  static const inviteFriends = IntroSlideData(
    titleTop: 'INVITE',
    titleBottom: 'FRIENDS',
    art: '${_p}invite_friends.webp',
    above: [IntroLine('Earn up to 5%*')],
    below: [
      IntroLine('for up to 2 years*'),
      IntroLine('on qualifying referral earnings'),
    ],
  );

  static const commission = IntroSlideData(
    titleTop: 'COMMISSION',
    titleBottom: 'STRUCTURE',
    art: '${_p}commission.webp',
    isCommission: true,
  );

  static const growNetwork = IntroSlideData(
    titleTop: 'GROW',
    titleBottom: 'NETWORK',
    art: '${_p}grow_network.webp',
    above: [IntroLine('Across')],
    below: [IntroLine('United Kingdom'), IntroLine('Northern Ireland')],
  );

  static const limitedPromo = IntroSlideData(
    titleTop: 'LIMITED',
    titleBottom: 'PROMOTION',
    art: '${_p}limited_promo.webp',
    above: [IntroLine('First 5000 signups')],
    below: [IntroLine('qualify for extra'), IntroLine('benefits*')],
  );

  static const moreOpportunities = IntroSlideData(
    titleTop: 'MORE',
    titleBottom: 'OPPORTUNITIES',
    art: '${_p}more_opportunities.webp',
    above: [IntroLine('We are creating more ways for')],
    below: [
      IntroLine('you to make money with us.'),
      IntroLine(' tuned', highlight: 'stay'),
    ],
  );

  static const stayTuned = IntroSlideData(
    titleTop: 'STAY',
    titleBottom: 'TUNED',
    art: '${_p}stay_tuned.webp',
    above: [
      IntroLine('We will inform you'),
      IntroLine('once we kick off the business'),
    ],
    below: [
      IntroLine('Start inviting friends now'),
      IntroLine('before someone else does'),
    ],
  );

  static const List<IntroSlideData> driver = [
    becomePartnerDriver,
    inviteFriends,
    commission,
    growNetwork,
    limitedPromo,
    moreOpportunities,
    stayTuned,
  ];

  static const List<IntroSlideData> business = [
    becomePartnerBusiness,
    inviteFriends,
    commission,
    growNetwork,
    moreOpportunities,
    stayTuned,
  ];

  // Cab drivers see the delivery driver slides until GoOuts Cab launches.
  static const List<IntroSlideData> cabDriver = driver;
}

/// Draws one slide on a fixed 420 x 800 design canvas (same placement as the
/// original artwork), scaled down to fit any screen.
class IntroSlideView extends StatelessWidget {
  final IntroSlideData slide;
  const IntroSlideView({super.key, required this.slide});

  static const double _w = 420;
  static const double _h = 800;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      alignment: Alignment.center,
      child: FittedBox(
        fit: BoxFit.contain,
        child: MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.noScaling),
          child: SizedBox(
            width: _w,
            height: _h,
            child: slide.isCommission ? _commission() : _standard(),
          ),
        ),
      ),
    );
  }

  Widget _titles() {
    return Column(
      children: [
        const SizedBox(height: 92),
        _fit(Text(
          slide.titleTop,
          style: const TextStyle(
            fontFamily: kIntroFont,
            fontSize: 40,
            fontWeight: FontWeight.w700,
            color: kIntroBlue,
            height: 1.15,
          ),
        )),
        _fit(Text(
          slide.titleBottom,
          style: const TextStyle(
            fontFamily: kIntroFont,
            fontSize: 38,
            fontWeight: FontWeight.w700,
            color: kIntroInk,
            height: 1.25,
          ),
        )),
      ],
    );
  }

  Widget _standard() {
    return Column(
      children: [
        _titles(),
        const SizedBox(height: 30),
        SizedBox(
          height: 245,
          width: 350,
          child: Image.asset(
            slide.art,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.image_not_supported_outlined,
              size: 80,
              color: kIntroBlue,
            ),
          ),
        ),
        const SizedBox(height: 22),
        ...slide.above.map(_line),
        const SizedBox(height: 4),
        _divider(),
        const SizedBox(height: 6),
        ...slide.below.map(_line),
        const Spacer(),
        _pill(),
        const SizedBox(height: 42),
      ],
    );
  }

  Widget _commission() {
    return Column(
      children: [
        _titles(),
        const SizedBox(height: 38),
        SizedBox(
          width: 300,
          child: AspectRatio(
            aspectRatio: 217 / 144,
            child: LayoutBuilder(builder: (context, c) {
              final double w = c.maxWidth;
              final double h = c.maxHeight;
              final tiers = kIntroCommissionTiers;
              // Label centres measured on the original artwork.
              const centres = [
                Offset(0.567, 0.60),
                Offset(0.700, 0.458),
                Offset(0.853, 0.313),
              ];
              return Stack(
                children: [
                  Positioned.fill(
                    child: Image.asset(
                      slide.art,
                      fit: BoxFit.fill,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                  for (int i = 0; i < 3 && i < tiers.length; i++)
                    Positioned(
                      left: centres[i].dx * w - 30,
                      top: centres[i].dy * h - h * 0.085,
                      width: 60,
                      child: Text(
                        tiers[i].percent,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: kIntroFont,
                          fontSize: h * 0.125,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1F2A44),
                          height: 1.0,
                        ),
                      ),
                    ),
                ],
              );
            }),
          ),
        ),
        const SizedBox(height: 18),
        _divider(),
        const SizedBox(height: 40),
        _table(),
        const SizedBox(height: 8),
        const Text(
          'Paid for up to 2 years* on qualifying referrals',
          style: TextStyle(
            fontFamily: kIntroFont,
            fontSize: 11,
            color: Color(0xFF555555),
          ),
        ),
        const Spacer(),
        _pill(),
        const SizedBox(height: 42),
      ],
    );
  }

  Widget _table() {
    const border = BorderSide(color: Color(0xFF1C3D5A), width: 0.6);
    const headStyle = TextStyle(
      fontFamily: kIntroFont,
      fontSize: 10.5,
      fontWeight: FontWeight.w700,
      color: Colors.white,
      height: 1.15,
    );
    const cellStyle = TextStyle(
      fontFamily: kIntroFont,
      fontSize: 10,
      color: Color(0xFF222222),
      height: 1.2,
    );

    Widget cell(Widget child, {bool head = false}) => Container(
          height: head ? 32 : 40,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: child,
        );

    return Container(
      width: 342,
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF1C3D5A), width: 0.8),
        borderRadius: BorderRadius.circular(3),
      ),
      clipBehavior: Clip.antiAlias,
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(0.9),
          1: FlexColumnWidth(1.2),
          2: FlexColumnWidth(1.9),
          3: FlexColumnWidth(1.9),
        },
        border: const TableBorder(
          horizontalInside: border,
          verticalInside: border,
        ),
        children: [
          TableRow(
            decoration: const BoxDecoration(color: Color(0xFF14A0D6)),
            children: [
              cell(const Text('Tier', style: headStyle), head: true),
              cell(
                  const Text('Successful\nReferrals',
                      textAlign: TextAlign.center, style: headStyle),
                  head: true),
              cell(const Text('Commission %', style: headStyle), head: true),
              cell(const Text('Notes', style: headStyle), head: true),
            ],
          ),
          for (final t in kIntroCommissionTiers)
            TableRow(
              children: [
                cell(Text(t.tier, style: cellStyle)),
                cell(Text(t.referrals, style: cellStyle)),
                cell(Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      t.percent,
                      style: const TextStyle(
                        fontFamily: kIntroFont,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: kIntroBlue,
                        height: 1.1,
                      ),
                    ),
                    const Text(
                      'of GoOuts profit',
                      style: TextStyle(
                        fontFamily: kIntroFont,
                        fontSize: 8.5,
                        color: Color(0xFF222222),
                      ),
                    ),
                  ],
                )),
                cell(Text(t.note,
                    textAlign: TextAlign.center, style: cellStyle)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _line(IntroLine l) {
    const style = TextStyle(
      fontFamily: kIntroFont,
      fontSize: 23,
      fontWeight: FontWeight.w500,
      color: kIntroInk,
      height: 1.3,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: _fit(Text.rich(
        TextSpan(children: [
          if (l.highlight != null)
            TextSpan(
              text: l.highlight,
              style: style.copyWith(color: kIntroBlue),
            ),
          TextSpan(text: l.text, style: style),
        ]),
        textAlign: TextAlign.center,
      )),
    );
  }

  Widget _divider() => Container(width: 252, height: 2.5, color: kIntroLine);

  Widget _pill() {
    return Container(
      width: 292,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: kIntroPill,
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Text(
        'GoOuts',
        style: TextStyle(
          fontFamily: kIntroFont,
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }

  static Widget _fit(Widget child) =>
      FittedBox(fit: BoxFit.scaleDown, child: child);
}

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

// firebase_app_check removed — DeviceCheck not configured in Firebase
import 'features/auth/business_referral_code_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/referral_code_screen.dart';
import 'features/auth/services/business_profile_service.dart';
import 'features/auth/services/driver_profile_service.dart';
import 'features/home/business_home_screen.dart';
import 'features/home/driver_home_screen.dart';
import 'features/messages/business_messages_inbox_screen.dart';
import 'features/messages/messages_inbox_screen.dart';
import 'features/support/support_ticket_chat_screen.dart';
import 'firebase_options.dart';
import 'features/legal/early_access_banner.dart';
import 'services/fcm_service.dart';
import 'package:driver_app/features/common/goouts_sheet.dart';



final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

final GlobalKey<NavigatorState> rootNavigatorKey =
    GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ── Crashlytics ─────────────────────────────────────────────────────────────
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };
  await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(!kDebugMode);

  await DriverFcmService.instance.initialize();

  runApp(const GoOutsDriverApp());
}

class GoOutsDriverApp extends StatelessWidget {
  const GoOutsDriverApp({super.key});

  static const Color _goOutsBlue = Color(0xFF0392CA);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GoOuts',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      navigatorKey: rootNavigatorKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _goOutsBlue,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const AppLaunchCoordinator(),
    );
  }
}

class AppLaunchCoordinator extends StatefulWidget {
  const AppLaunchCoordinator({super.key});

  @override
  State<AppLaunchCoordinator> createState() => _AppLaunchCoordinatorState();
}

class _AppLaunchCoordinatorState extends State<AppLaunchCoordinator> {
  StreamSubscription<RemoteMessage>? _foregroundMessageSubscription;
  StreamSubscription<RemoteMessage>? _openedMessageSubscription;

  bool _isCheckingInitialLink = false;
  InviteLaunchData? _inviteLaunchData;

  @override
  void initState() {
    super.initState();
    _initFcmHandling();
  }

  @override
  void dispose() {
    _foregroundMessageSubscription?.cancel();
    _openedMessageSubscription?.cancel();
    super.dispose();
  }

  void _initFcmHandling() {
    _foregroundMessageSubscription =
        DriverFcmService.instance.foregroundMessages.listen(
      _handleForegroundMessage,
    );

    _openedMessageSubscription =
        DriverFcmService.instance.openedMessages.listen(
      _handleOpenedMessage,
    );

    final RemoteMessage? initialOpenedMessage =
        DriverFcmService.instance.consumeInitialOpenedMessage();

    if (initialOpenedMessage != null) {
      unawaited(_handleOpenedMessage(initialOpenedMessage));
    }

    unawaited(
      DriverFcmService.instance.syncTokenForCurrentUser(),
    );
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final String title =
        (message.notification?.title ?? '').trim().isNotEmpty
            ? message.notification!.title!.trim()
            : 'New notification';

    final String body =
        (message.notification?.body ?? '').trim().isNotEmpty
            ? message.notification!.body!.trim()
            : 'You have received a new update.';

    final _ctx = rootNavigatorKey.currentContext;
    if (_ctx != null) GoOutsSheet.info(_ctx, title: title, message: body);
  }

  Future<String> _readPendingAccountTypeValue() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String value = prefs
            .getString(AuthProfileGate._pendingAccountTypeKey)
            ?.trim()
            .toLowerCase() ??
        'driver';

    if (value == 'business') {
      return 'business';
    }

    if (value == 'cab_driver') {
      return 'cab_driver';
    }

    return 'driver';
  }

  Future<String> _resolveCurrentAccountType(User user) async {
    try {
      final DocumentSnapshot<Map<String, dynamic>> businessDoc =
          await FirebaseFirestore.instance
              .collection('businesses')
              .doc(user.uid)
              .get();
      if (businessDoc.exists) {
        return 'business';
      }

      final DocumentSnapshot<Map<String, dynamic>> driverDoc =
          await FirebaseFirestore.instance
              .collection('drivers')
              .doc(user.uid)
              .get();
      if (driverDoc.exists) {
        return 'driver';
      }
    } catch (_) {
      // Fall back to the pending account type below.
    }

    return _readPendingAccountTypeValue();
  }

  bool _isValidReferralCode(String code) {
  final String value = code.trim().toUpperCase();
  final RegExp driverPattern = RegExp(r'^G\d{5}$');
  final RegExp businessPattern = RegExp(r'^GB\d{4}$');
  final RegExp cabDriverPattern = RegExp(r'^GC\d{6}$');
  return driverPattern.hasMatch(value) ||
      businessPattern.hasMatch(value) ||
      cabDriverPattern.hasMatch(value);
}

  String _safeReferralCode(String value) {
    final String normalized = _normalizedCode(value);
    if (_isValidReferralCode(normalized)) {
      return normalized;
    }
    return '';
  }

  Future<void> _handleOpenedMessage(RemoteMessage message) async {
    // 1. Check for referral deep-link first
    final InviteLaunchData? resolvedFromMessage =
        await _resolveInviteLaunchDataFromMessage(message);

    if (!mounted) return;

    if (resolvedFromMessage != null) {
      setState(() => _inviteLaunchData = resolvedFromMessage);
      final _rCtx = rootNavigatorKey.currentContext;
      if (_rCtx != null) GoOutsSheet.info(_rCtx, title: 'Referral', message: 'Referral link detected from notification.');
      return;
    }

    if (FirebaseAuth.instance.currentUser == null) {
      final _lCtx = rootNavigatorKey.currentContext;
      if (_lCtx != null) GoOutsSheet.warning(_lCtx, title: 'Login Required', message: 'Please log in to view your messages.');
      return;
    }

    final User user = FirebaseAuth.instance.currentUser!;

    // 2. Support ticket notification → open ticket chat directly
    final String ticketId =
        (message.data['ticketId'] ?? '').toString().trim();
    if (ticketId.isNotEmpty) {
      await _openTicketChatFromNotification(user, message, ticketId);
      return;
    }

    // 3. Regular message → open inbox
    final String accountType = await _resolveCurrentAccountType(user);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      rootNavigatorKey.currentState?.push(MaterialPageRoute(
        builder: (_) => accountType == 'business'
            ? const BusinessMessagesInboxScreen()
            : const MessagesInboxScreen(),
      ));
    });
  }

  Future<void> _openTicketChatFromNotification(
      User user, RemoteMessage message, String ticketId) async {
    final String accountType = await _resolveCurrentAccountType(user);

    final String collection = accountType == 'business'
        ? 'businesses'
        : accountType == 'cab_driver'
            ? 'cab_drivers'
            : 'drivers';

    // Fetch driver name
    String driverName = 'Driver';
    try {
      final doc = await FirebaseFirestore.instance
          .collection(collection)
          .doc(user.uid)
          .get();
      final d = doc.data() ?? {};
      final first = (d['firstName'] ?? '').toString().trim();
      final last  = (d['surname'] ?? d['lastName'] ?? '').toString().trim();
      final full  = [first, last].where((s) => s.isNotEmpty).join(' ');
      if (full.isNotEmpty) driverName = full;
    } catch (_) {}

    final String rawTicketNum =
        (message.data['ticketNumber'] ?? '').toString().trim();
    final String ticketNumber = rawTicketNum.isNotEmpty
        ? (rawTicketNum.startsWith('SR-') ? rawTicketNum : 'SR-$rawTicketNum')
        : 'SR-${ticketId.substring(0, ticketId.length >= 8 ? 8 : ticketId.length).toUpperCase()}';

    final String subject = (message.data['title'] ??
            message.notification?.title ??
            'Support Request')
        .toString()
        .trim();

    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      rootNavigatorKey.currentState?.push(MaterialPageRoute(
        builder: (_) => SupportTicketChatScreen(
          ticketId:         ticketId,
          subject:          subject.isEmpty ? 'Support Request' : subject,
          ticketNumber:     ticketNumber,
          driverName:       driverName,
          sourceCollection: collection,
        ),
      ));
    });
  }

  String _normalizedValue(String value) {
    return value.trim();
  }

  String _normalizedCode(String value) {
    return value.trim().toUpperCase();
  }

  String _normalizedDynamicValue(dynamic value) {
    return value == null ? '' : value.toString().trim();
  }

  String _readReferralCodeFromUri(Uri uri) {
    const List<String> keys = [
      'referralCode',
      'referral_code',
      'code',
      'ref',
    ];

    for (final String key in keys) {
      final String value = _safeReferralCode(uri.queryParameters[key] ?? '');
      if (value.isNotEmpty) {
        return value;
      }
    }

    return '';
  }

  String _readReferralCodeFromData(Map<String, dynamic> data) {
    const List<String> keys = [
      'referralCode',
      'referral_code',
      'code',
      'ref',
    ];

    for (final String key in keys) {
      final String value = _safeReferralCode(
        _normalizedDynamicValue(data[key]),
      );
      if (value.isNotEmpty) {
        return value;
      }
    }

    return '';
  }

  String _readInviteTokenFromData(Map<String, dynamic> data) {
    const List<String> keys = [
      'token',
      'inviteToken',
      'invite_token',
    ];

    for (final String key in keys) {
      final String value = _normalizedCode(
        _normalizedDynamicValue(data[key]),
      );
      if (value.isNotEmpty) {
        return value;
      }
    }

    return '';
  }

  String _readDeepLinkFromData(Map<String, dynamic> data) {
    const List<String> keys = [
      'deepLink',
      'deep_link',
      'link',
      'url',
    ];

    for (final String key in keys) {
      final String value = _normalizedDynamicValue(data[key]);
      if (value.isNotEmpty) {
        return value;
      }
    }

    return '';
  }

  Future<InviteLaunchData?> _resolveInviteLaunchDataFromMessage(
    RemoteMessage message,
  ) async {
    final Map<String, dynamic> data = message.data;

    final String deepLinkValue = _readDeepLinkFromData(data);
    if (deepLinkValue.isNotEmpty) {
      try {
        final Uri uri = Uri.parse(deepLinkValue);
        final InviteLaunchData? resolved =
            await _resolveInviteLaunchData(uri);
        if (resolved != null) {
          return resolved;
        }
      } catch (_) {
        // Ignore malformed notification deep links and try direct fields.
      }
    }

    final String inviteToken = _readInviteTokenFromData(data);
    final String referralCode = _readReferralCodeFromData(data);

    if (inviteToken.isEmpty && referralCode.isEmpty) {
      return null;
    }

    if (inviteToken.isNotEmpty) {
      try {
        final DocumentSnapshot<Map<String, dynamic>> inviteSnapshot =
            await FirebaseFirestore.instance
                .collection('invites')
                .doc(inviteToken)
                .get();

        if (inviteSnapshot.exists) {
          final Map<String, dynamic>? inviteData = inviteSnapshot.data();
          final String referralCodeFromInvite = _safeReferralCode(
            (inviteData?['referralCode'] ?? '').toString(),
          );

          final String resolvedReferralCode = referralCodeFromInvite.isNotEmpty
              ? referralCodeFromInvite
              : referralCode;

          if (resolvedReferralCode.isNotEmpty) {
            return InviteLaunchData(
              inviteToken: inviteToken,
              referralCode: resolvedReferralCode,
            );
          }
        }
      } catch (_) {
        // Fall back to referral-code-only flow below if available.
      }
    }

    if (referralCode.isNotEmpty) {
      return InviteLaunchData(
        inviteToken: _normalizedValue(inviteToken),
        referralCode: referralCode,
      );
    }

    return null;
  }

  Future<InviteLaunchData?> _resolveInviteLaunchData(Uri uri) async {
    final String inviteToken = _normalizedCode(
      uri.queryParameters['token'] ?? '',
    );
    final String referralCodeFromUri = _readReferralCodeFromUri(uri);

    if (inviteToken.isEmpty && referralCodeFromUri.isEmpty) {
      return null;
    }

    if (inviteToken.isNotEmpty) {
      try {
        final DocumentSnapshot<Map<String, dynamic>> inviteSnapshot =
            await FirebaseFirestore.instance
                .collection('invites')
                .doc(inviteToken)
                .get();

        if (inviteSnapshot.exists) {
          final Map<String, dynamic>? inviteData = inviteSnapshot.data();
          final String referralCodeFromInvite = _safeReferralCode(
            (inviteData?['referralCode'] ?? '').toString(),
          );

          final String resolvedReferralCode = referralCodeFromInvite.isNotEmpty
              ? referralCodeFromInvite
              : referralCodeFromUri;

          if (resolvedReferralCode.isNotEmpty) {
            return InviteLaunchData(
              inviteToken: inviteToken,
              referralCode: resolvedReferralCode,
            );
          }
        }
      } catch (_) {
        // Fall back to referral-code-only flow below if available.
      }
    }

    if (referralCodeFromUri.isNotEmpty) {
      return InviteLaunchData(
        inviteToken: _normalizedValue(inviteToken),
        referralCode: referralCodeFromUri,
      );
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingInitialLink) {
      return const SplashLoadingScreen();
    }

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const SplashLoadingScreen();
        }

        final User? user = authSnapshot.data;

        if (user == null) {
          return const DriverSplashScreen();
        }

        return AuthProfileGate(
          inviteLaunchData: _inviteLaunchData,
        );
      },
    );
  }
}

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  static const Color _goOutsBlue = Color(0xFF0392CA);
  static const Color _businessOrange = Color(0xFFF97316);
  // static const Color _cabGreen = Color(0xFF22C55E); // reserved — uncomment when cab driver role is enabled
  static const String _selectedAccountTypeKey = 'selected_account_type';
  static const String _driverIntroDontShowAgainKey =
      'driver_intro_dont_show_again';
  static const String _businessIntroDontShowAgainKey =
      'business_intro_dont_show_again';

  Future<void> _openRoleIntro(
    BuildContext context,
    String accountType,
  ) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedAccountTypeKey, accountType);
    await prefs.setString('pending_account_type', accountType);

    final bool skipIntro = accountType == 'business'
        ? prefs.getBool(_businessIntroDontShowAgainKey) == true
        : accountType == 'cab_driver'
            ? prefs.getBool('cab_driver_intro_dont_show_again') == true
            : prefs.getBool(_driverIntroDontShowAgainKey) == true;

    if (!context.mounted) {
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        settings: RouteSettings(
          arguments: {'accountType': accountType},
        ),
        builder: (_) =>
            skipIntro
                ? const LoginScreen()
                : RoleIntroSlidesScreen(accountType: accountType),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 48,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 360),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 32),
                        Center(
                          child: Image.asset(
                            'assets/logo/goouts_logo_login.png',
                            height: 180,
                            fit: BoxFit.contain,
                            color: _goOutsBlue,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'SELECT YOUR ROLE',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: Colors.black87,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Select the option that matches you best.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            color: Color(0xFF64748B),
                            height: 1.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const EarlyAccessBanner(),
                        const SizedBox(height: 14),
                        _RoleCardButton(
                          title: 'Delivery Driver',
                          subtitle: 'Continue as Delivery Driver',
                          icon: Icons.delivery_dining_rounded,
                          backgroundColor: _goOutsBlue,
                          onTap: () => _openRoleIntro(context, 'driver'),
                        ),
                        // ── CAB DRIVER — hidden until post-launch activation ──
                        // const SizedBox(height: 14),
                        // _RoleCardButton(
                        //   title: 'Rider Driver',
                        //   subtitle: 'Continue as Rider Driver',
                        //   icon: Icons.local_taxi_rounded,
                        //   backgroundColor: _cabGreen,
                        //   onTap: () => _openRoleIntro(context, 'cab_driver'),
                        // ),
                        const SizedBox(height: 14),
                        _RoleCardButton(
                          title: 'Business Partner',
                          subtitle: 'Continue as Business',
                          icon: Icons.storefront_rounded,
                          backgroundColor: _businessOrange,
                          onTap: () => _openRoleIntro(context, 'business'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _RoleCardButton extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color backgroundColor;
  final VoidCallback onTap;

  const _RoleCardButton({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.backgroundColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: backgroundColor.withOpacity(0.16),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 14,
            ),
            child: Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Image.asset(
                      'assets/logo/role_icon.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          subtitle,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class RoleIntroSlidesScreen extends StatefulWidget {
  final String accountType;
  final bool openedFromMenu;

  const RoleIntroSlidesScreen({
    super.key,
    required this.accountType,
    this.openedFromMenu = false,
  });

  @override
  State<RoleIntroSlidesScreen> createState() => _RoleIntroSlidesScreenState();
}

class _RoleIntroSlidesScreenState extends State<RoleIntroSlidesScreen> {
  static const Color _goOutsBlue = Color(0xFF0392CA);
  static const String _driverIntroDontShowAgainKey =
      'driver_intro_dont_show_again';
  static const String _businessIntroDontShowAgainKey =
      'business_intro_dont_show_again';

  static const List<String> _driverSlides = [
    'assets/intro/Become Partner_2.png',
    'assets/intro/Invite Friends_3.png',
    'assets/intro/Commission Structure_3a.png',
    'assets/intro/Grow Network_4.png',
    'assets/intro/Limited Promo_5.png',
    'assets/intro/More opportunities_6.png',
    'assets/intro/Stay tuned_7.png',
  ];

  static const List<String> _businessSlides = [
    'assets/intro/Become Partner_2a.png',
    'assets/intro/Invite Friends_3.png',
    'assets/intro/Commission Structure_3a.png',
    'assets/intro/Grow Network_4.png',
    'assets/intro/More opportunities_6.png',
    'assets/intro/Stay tuned_7.png',
  ];

  static const List<String> _cabDriverSlides = [
    'assets/intro/Become Partner_2b.png',
    'assets/intro/Invite Friends_3.png',
    'assets/intro/Commission Structure_3a.png',
    'assets/intro/Grow Network_4.png',
    'assets/intro/Limited Promo_5.png',
    'assets/intro/More opportunities_6.png',
    'assets/intro/Stay tuned_7.png',
  ];

  final PageController _pageController = PageController();

  int _currentIndex = 0;
  bool _isFinishing = false;

 List<String> get _slides {
    if (widget.accountType == 'business') {
      return _businessSlides;
    }
    if (widget.accountType == 'cab_driver') {
      return _cabDriverSlides;
    }
    return _driverSlides;
  }

  bool get _isLastSlide => _currentIndex == _slides.length - 1;
  bool get _showBackButton => true;
  bool get _showNextButton => !_isLastSlide;
  bool get _showIndicator => true;

  Future _finishIntro() async {
  if (_isFinishing) {
    return;
  }

  _isFinishing = true;

  if (!mounted) {
    return;
  }

  if (widget.openedFromMenu) {
    Navigator.of(context).pop();
    return;
  }

  Navigator.of(context).pushReplacement(
    MaterialPageRoute(
      settings: RouteSettings(
        arguments: {
          'accountType': widget.accountType,
        },
      ),
      builder: (_) => const LoginScreen(),
    ),
  );
}

  Future<void> _finishAndHideIntroNextTime() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    if (widget.accountType == 'business') {
      await prefs.setBool(_businessIntroDontShowAgainKey, true);
    } else if (widget.accountType == 'cab_driver') {
      await prefs.setBool('cab_driver_intro_dont_show_again', true);
    } else {
      await prefs.setBool(_driverIntroDontShowAgainKey, true);
    }

    await _finishIntro();
  }

  void _nextSlide() {
    if (_isLastSlide) {
      return;
    }

    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _previousSlide() {
    if (_currentIndex <= 0) {
      return;
    }

    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _handleBack() {
    if (_currentIndex == 0) {
      Navigator.of(context).pop();
    } else {
      _previousSlide();
    }
  }

  Widget _buildTopBar() {
    if (_isLastSlide) {
      return SizedBox(
        height: 56,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              if (_showBackButton)
                TextButton.icon(
                  onPressed: _handleBack,
                  icon: const Icon(Icons.arrow_back_ios_new, size: 16),
                  label: const Text(
                    'BACK',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: _goOutsBlue,
                  ),
                )
              else
                const SizedBox(width: 12),
              const Spacer(),
              TextButton.icon(
                onPressed: _finishAndHideIntroNextTime,
                icon: const Text(
                  'FINISH',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                label: const Icon(Icons.arrow_forward_ios, size: 16),
                style: TextButton.styleFrom(
                  foregroundColor: _goOutsBlue,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 56,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (_showBackButton)
              TextButton.icon(
                onPressed: _previousSlide,
                icon: const Icon(Icons.arrow_back_ios_new, size: 16),
                label: const Text(
                  'BACK',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: _goOutsBlue,
                ),
              )
            else
              const SizedBox(width: 12),
            if (_showNextButton)
              TextButton.icon(
                onPressed: _nextSlide,
                icon: const Text(
                  'NEXT',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                label: const Icon(Icons.arrow_forward_ios, size: 16),
                style: TextButton.styleFrom(
                  foregroundColor: _goOutsBlue,
                ),
              )
            else
              const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildIndicator() {
    if (!_showIndicator) {
      return const SizedBox(height: 24);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: SmoothPageIndicator(
        controller: _pageController,
        count: _slides.length,
        effect: ExpandingDotsEffect(
          activeDotColor: _goOutsBlue,
          dotColor: _goOutsBlue.withOpacity(0.18),
          dotHeight: 8,
          dotWidth: 8,
          expansionFactor: 3.2,
          spacing: 8,
          radius: 12,
        ),
        onDotClicked: (index) {
          _pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        },
      ),
    );
  }

  Widget _buildSlide(String path) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      child: Center(
        child: Image.asset(
          path,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _slides.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentIndex = index;
                  });
                },
                itemBuilder: (_, i) => _buildSlide(_slides[i]),
              ),
            ),
            _buildIndicator(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class AuthProfileGate extends StatelessWidget {
  final InviteLaunchData? inviteLaunchData;

  const AuthProfileGate({
    super.key,
    this.inviteLaunchData,
  });

  static const String _pendingAccountTypeKey = 'pending_account_type';

  Future<String> _readPendingAccountType() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String value =
        prefs.getString(_pendingAccountTypeKey)?.trim().toLowerCase() ??
            'driver';

    if (value == 'business') {
      return 'business';
    }

    if (value == 'cab_driver') {
      return 'cab_driver';
    }

    return 'driver';
  }

  Future<bool> _businessProfileExists(String uid) async {
    return BusinessProfileService().businessProfileExists(uid);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _readPendingAccountType(),
      builder: (context, accountTypeSnapshot) {
        if (accountTypeSnapshot.connectionState == ConnectionState.waiting) {
          return const SplashLoadingScreen();
        }

        final String accountType = accountTypeSnapshot.data ?? 'driver';
        final User? user = FirebaseAuth.instance.currentUser;

        if (user == null) {
          return const RoleSelectionScreen();
        }

        if (accountType == 'business') {
          return FutureBuilder<bool>(
            future: _businessProfileExists(user.uid),
            builder: (context, businessSnapshot) {
              if (businessSnapshot.connectionState == ConnectionState.waiting) {
                return const SplashLoadingScreen();
              }

              if (businessSnapshot.hasError) {
                return AppErrorScreen(
                  message:
                      'Failed to check business profile.\n${businessSnapshot.error}',
                );
              }

              final bool profileExists = businessSnapshot.data ?? false;

              if (!profileExists) {
                return BusinessReferralCodeScreen(
                  inviteToken: inviteLaunchData?.inviteToken,
                  prefilledReferralCode: inviteLaunchData?.referralCode,
                );
              }

              return const BusinessHomeScreen();
            },
          );
        }

        if (accountType == 'cab_driver') {
          return FutureBuilder<bool>(
            future: FirebaseFirestore.instance
                .collection('cab_drivers')
                .doc(user.uid)
                .get()
                .then((doc) => doc.exists),
            builder: (context, cabSnapshot) {
              if (cabSnapshot.connectionState == ConnectionState.waiting) {
                return const SplashLoadingScreen();
              }
              if (cabSnapshot.hasError) {
                return AppErrorScreen(
                  message:
                      'Failed to check cab driver profile.\n${cabSnapshot.error}',
                );
              }
              final bool profileExists = cabSnapshot.data ?? false;
              if (!profileExists) {
                return ReferralCodeScreen(
                  inviteToken: inviteLaunchData?.inviteToken,
                  prefilledReferralCode: inviteLaunchData?.referralCode,
                  accountType: 'cab_driver',
                );
              }
              return const DriverHomeScreen();
            },
          );
        }

        return StreamBuilder<bool>(
          stream: DriverProfileService().driverProfileExistsStream(user.uid),
          builder: (context, profileSnapshot) {
            if (profileSnapshot.connectionState == ConnectionState.waiting) {
              return const SplashLoadingScreen();
            }

            if (profileSnapshot.hasError) {
              return AppErrorScreen(
                message:
                    'Failed to check driver profile.\n${profileSnapshot.error}',
              );
            }

            final bool profileExists = profileSnapshot.data ?? false;

            if (!profileExists) {
              return ReferralCodeScreen(
                inviteToken: inviteLaunchData?.inviteToken,
                prefilledReferralCode: inviteLaunchData?.referralCode,
                accountType: 'driver',
              );
            }

            return const DriverHomeScreen();
          },
        );
      },
    );
  }
}

// ── Driver Splash Screen ──────────────────────────────────────────────────────

class DriverSplashScreen extends StatefulWidget {
  const DriverSplashScreen({super.key});

  @override
  State<DriverSplashScreen> createState() => _DriverSplashScreenState();
}

class _DriverSplashScreenState extends State<DriverSplashScreen>
    with TickerProviderStateMixin {
  static const Color _blue = Color(0xFF0392CA);

  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnim =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));
    _fadeController.forward();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.03).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _getStarted() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
    );
  }

  void _signIn() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [Color(0xFF0392CA), Color(0xFF026899)],
          ),
        ),
        child: Stack(
          children: [
            CustomPaint(
              size: Size(MediaQuery.of(context).size.width,
                  MediaQuery.of(context).size.height),
              painter: _SplashStreaksPainter(),
            ),
            Positioned(
              right: 16,
              bottom: 140,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _bar(48),
                  const SizedBox(height: 6),
                  _bar(32),
                  const SizedBox(height: 6),
                  _bar(20),
                ],
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  const Spacer(flex: 3),
                  FadeTransition(
                    opacity: _fadeAnim,
                    child: ScaleTransition(
                      scale: _pulseAnim,
                      child: SlideTransition(
                        position: _slideAnim,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 52),
                          child: Container(
                            clipBehavior: Clip.antiAlias,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 22),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.22),
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
                                  blurRadius: 24,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Image.asset(
                                  'assets/logo/goouts_logo_white.png',
                                  height: 150,
                                  width: 150,
                                  fit: BoxFit.contain,
                                  filterQuality: FilterQuality.high,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.local_shipping_rounded,
                                    size: 90,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'GoOuts',
                                  style: TextStyle(
                                    fontSize: 30,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Your journey.\nYour income. Your future.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white.withOpacity(0.95),
                                    height: 1.55,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'DRIVE  ||  DELIVER  ||  EARN  ||  GROW',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'JOIN THE GOOUTS DRIVER NETWORK',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withOpacity(0.80),
                      letterSpacing: 1.8,
                    ),
                  ),
                  const Spacer(flex: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _dot(false),
                      const SizedBox(width: 8),
                      _dot(true),
                      const SizedBox(width: 8),
                      _dot(false),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: OutlinedButton.icon(
                        onPressed: _getStarted,
                        icon: const Icon(Icons.bolt_rounded,
                            color: Colors.white, size: 20),
                        label: const Text(
                          'GET STARTED',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            letterSpacing: 1.8,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                              color: Colors.white.withOpacity(0.55),
                              width: 1.5),
                          backgroundColor: Colors.white.withOpacity(0.08),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(50),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: _signIn,
                    child: RichText(
                      text: TextSpan(
                        text: 'Already registered? ',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.75),
                        ),
                        children: const [
                          TextSpan(
                            text: 'Sign In',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              decoration: TextDecoration.underline,
                              decorationColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dot(bool active) => AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: active ? 14 : 8,
        height: 8,
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.white.withOpacity(0.35),
          borderRadius: BorderRadius.circular(4),
        ),
      );

  Widget _bar(double height) => Container(
        width: 4,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.25),
          borderRadius: BorderRadius.circular(2),
        ),
      );
}

class _SplashStreaksPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final bandPaint = Paint()..style = PaintingStyle.stroke;
    final bands = [
      [0.6, 0.0, -0.1, 0.7, 0.55, 0.35, 60.0, 0.06],
      [0.65, 0.0, -0.05, 0.75, 0.60, 0.38, 30.0, 0.09],
      [0.70, 0.0, 0.0, 0.80, 0.65, 0.40, 12.0, 0.15],
      [0.75, 0.0, 0.05, 0.85, 0.70, 0.42, 5.0, 0.20],
      [0.80, 0.0, 0.10, 0.90, 0.75, 0.45, 2.5, 0.12],
    ];
    for (final b in bands) {
      final path = Path()
        ..moveTo(w * b[0], h * b[1])
        ..quadraticBezierTo(w * b[4], h * b[5], w * b[2], h * b[3]);
      bandPaint
        ..color = Colors.white.withOpacity(b[7])
        ..strokeWidth = b[6];
      canvas.drawPath(path, bandPaint);
    }
    final bubblePaint = Paint()..style = PaintingStyle.fill;
    final bubbles = [
      [0.08, 0.05, 18.0, 0.10], [0.22, 0.12, 12.0, 0.08],
      [0.55, 0.08, 22.0, 0.09], [0.80, 0.15, 14.0, 0.10],
      [0.92, 0.04, 10.0, 0.07], [0.05, 0.25, 10.0, 0.08],
      [0.35, 0.22, 16.0, 0.07], [0.68, 0.28, 12.0, 0.09],
      [0.88, 0.32, 18.0, 0.08], [0.15, 0.42, 14.0, 0.07],
      [0.48, 0.38, 10.0, 0.10], [0.78, 0.45, 16.0, 0.08],
      [0.05, 0.55, 20.0, 0.08], [0.28, 0.58, 12.0, 0.09],
      [0.60, 0.55, 18.0, 0.07], [0.82, 0.62, 12.0, 0.10],
      [0.12, 0.70, 10.0, 0.08], [0.42, 0.72, 16.0, 0.07],
      [0.70, 0.75, 10.0, 0.09], [0.90, 0.78, 18.0, 0.08],
      [0.20, 0.85, 14.0, 0.07], [0.55, 0.88, 12.0, 0.09],
      [0.78, 0.92, 10.0, 0.08], [0.35, 0.95, 16.0, 0.07],
    ];
    for (final b in bubbles) {
      bubblePaint.color = Colors.white.withOpacity(b[3]);
      canvas.drawCircle(Offset(w * b[0], h * b[1]), b[2], bubblePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class SplashLoadingScreen extends StatelessWidget {
  const SplashLoadingScreen({super.key});

  static const Color _goOutsBlue = Color(0xFF0392CA);

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: CircularProgressIndicator(
          color: _goOutsBlue,
        ),
      ),
    );
  }
}

class AppErrorScreen extends StatelessWidget {
  final String message;

  const AppErrorScreen({
    super.key,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            message,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

class InviteLaunchData {
  final String inviteToken;
  final String referralCode;

  const InviteLaunchData({
    required this.inviteToken,
    required this.referralCode,
  });
}

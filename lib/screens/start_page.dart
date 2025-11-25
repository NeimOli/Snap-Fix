import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/notification_permission_service.dart';
import '../services/camera_permission_service.dart';

class StartPage extends StatefulWidget {
  const StartPage({super.key});

  @override
  State<StartPage> createState() => _StartPageState();
}

class _StartPageState extends State<StartPage> with SingleTickerProviderStateMixin {
  late final PageController _adsController;
  int _currentAdPage = 0;
  Timer? _adsTimer;

  late final AnimationController _animController;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _titleOpacity;
  late final Animation<double> _cardOpacity;
  late final Animation<double> _adsOpacity;

  final List<Map<String, String>> _ads = const [
    {
      'title': 'Scan & fix in minutes',
      'description': 'Use AI to detect issues and get instant DIY steps.',
    },
    {
      'title': 'Find trusted pros',
      'description': 'Book verified technicians when you need extra help.',
    },
    {
      'title': 'Track your history',
      'description': 'All your past analyses saved in one place.',
    },
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _logoOpacity = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
    );
    _titleOpacity = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.2, 0.5, curve: Curves.easeOut),
    );
    _cardOpacity = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.4, 0.9, curve: Curves.easeOut),
    );
    _adsOpacity = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.6, 1.0, curve: Curves.easeOut),
    );

    _adsController = PageController(viewportFraction: 0.8);
    _startAdsAutoScroll();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationPermissionService.requestPermissionIfNeeded(context);
      CameraPermissionService.requestPermissionIfNeeded(context);
    });

    _animController.forward();
  }

  void _startAdsAutoScroll() {
    _adsTimer?.cancel();
    if (_ads.isEmpty) return;

    _adsTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_adsController.hasClients) return;
      final nextPage = (_currentAdPage + 1) % _ads.length;
      _adsController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
      _currentAdPage = nextPage;
    });
  }

  @override
  void dispose() {
    _adsTimer?.cancel();
    _adsController.dispose();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF4C1D95),
              Color(0xFF6D28D9),
              Color(0xFF7C3AED),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      // App Icon
                      FadeTransition(
                        opacity: _logoOpacity,
                        child: _buildAppIcon(),
                      ),
                      const SizedBox(height: 24),
                      // Welcome Message
                      FadeTransition(
                        opacity: _titleOpacity,
                        child: Column(
                          children: [
                            Text(
                              'Welcome to SnapFix',
                              style: GoogleFonts.inter(
                                fontSize: 32,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Instant Photo-Based Problem Solver',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w400,
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),
                      // Get Started Card
                      FadeTransition(
                        opacity: _cardOpacity,
                        child: _buildGetStartedCard(context),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
              // Footer
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: FadeTransition(
                  opacity: _adsOpacity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _buildAdsSection(),
                      const SizedBox(height: 16),
                      Text(
                        'Built with ❤️ for SnapFix',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppIcon() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Diamond shape
            Container(
              width: 12,
              height: 12,
              decoration: const BoxDecoration(
                color: Color(0xFF6366F1),
              ),
              transform: Matrix4.rotationZ(0.785398), // 45 degrees
            ),
            const SizedBox(height: 6),
            // Circle
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Color(0xFF6366F1),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(height: 6),
            // Inverted V (Chevron down)
            SizedBox(
              width: 12,
              height: 8,
              child: CustomPaint(
                painter: StartPageChevronPainter(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGetStartedCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Heading
          Text(
            'Get Started',
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Colors.grey[900],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Login or create an account to sync your fixes and history.',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          // Login Button
          _buildLoginButton(context),
          const SizedBox(height: 12),
          // Create Account Button
          _buildCreateAccountButton(context),
          const SizedBox(height: 32),
          // Feature Grid
          _buildFeatureGrid(),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.center,
            child: TextButton(
              onPressed: () => context.go('/provider-register'),
              child: Text(
                'I am a service provider',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF6366F1),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          context.go('/login');
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF6366F1),
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 3,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.arrow_forward,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Login to Your Account',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateAccountButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: () {
          context.go('/register');
        },
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          side: const BorderSide(
            color: Color(0xFF6366F1),
            width: 1.8,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.person_add,
              color: Color(0xFF6366F1),
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Create New Account',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF6366F1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureGrid() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildFeatureItem(
                icon: Icons.camera_alt,
                title: 'Photo Capture',
                description: 'Snap a photo of your problem',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildFeatureItem(
                icon: Icons.search,
                title: 'AI Analysis',
                description: 'Get instant problem identification',
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildFeatureItem(
                icon: Icons.build,
                title: 'DIY Guides',
                description: 'Step-by-step repair instructions',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildFeatureItem(
                icon: Icons.person,
                title: 'Find Pros',
                description: 'Connect with local experts',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF6366F1),
              size: 24,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[900],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: Colors.grey[600],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildAdsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What you can do with SnapFix',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[900],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 120,
          child: PageView.builder(
            controller: _adsController,
            itemCount: _ads.length,
            onPageChanged: (index) {
              _currentAdPage = index;
            },
            itemBuilder: (context, index) {
              final ad = _ads[index];
              return _buildAdCard(
                title: ad['title'] ?? '',
                description: ad['description'] ?? '',
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAdCard({required String title, required String description}) {
    return Container(
      width: 220,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFEEF2FF),
            Color(0xFFE0ECFF),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.grey[900],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: Colors.grey[700],
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// Custom painter for the inverted V (chevron down) shape in start page
class StartPageChevronPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF6366F1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    // Draw inverted V shape (chevron pointing down)
    path.moveTo(0, 0); // Top left
    path.lineTo(size.width / 2, size.height); // Bottom center
    path.lineTo(size.width, 0); // Top right

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}


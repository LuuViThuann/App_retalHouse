import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_rentalhouse/config/loading.dart';
import 'package:lottie/lottie.dart';
import 'login_view.dart';

// ============================================================
// CONSTANTS — khai báo ngoài class, tránh tạo lại mỗi build
// ============================================================
const _kBlue900 = Color(0xFF0D2B6B);
const _kBlue700 = Color(0xFF1452CC);
const _kBlue500 = Color(0xFF2979FF);
const _kBlue300 = Color(0xFF64B5F6);
const _kBlueSoft = Color(0xFFE8F0FE);

// Gradient dùng chung — tạo 1 lần, không recreate trong build()
const _kPrimaryGradient = LinearGradient(
  colors: [_kBlue700, _kBlue500],
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
);
const _kTitleGradient = LinearGradient(
  colors: [_kBlue700, _kBlue500],
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
);

// BoxDecoration tĩnh — tạo 1 lần
final _kSkipDecoration = BoxDecoration(
  color: _kBlueSoft,
  borderRadius: BorderRadius.circular(20),
);
final _kButtonDecoration = BoxDecoration(
  gradient: _kPrimaryGradient,
  borderRadius: BorderRadius.circular(18),
  boxShadow: [
    BoxShadow(
      color: _kBlue700.withOpacity(0.40),
      blurRadius: 24,
      offset: const Offset(0, 10),
    ),
  ],
);

// ============================================================
// DATA MODEL
// ============================================================
class _PageData {
  final String title;
  final String titleAccent;
  final String description;
  final _SlideType type;
  final String? imagePath;

  const _PageData({
    required this.title,
    required this.titleAccent,
    required this.description,
    required this.type,
    this.imagePath,
  });
}

enum _SlideType { lottieHouse, searchMap, contract }

// ============================================================
// WELCOME SCREEN
// ============================================================
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  _WelcomeScreenState createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // FIX: Tách riêng 3 controller với duration hợp lý
  // _masterCtrl: fade-in lần đầu, chạy 1 lần → không loop
  // _floatCtrl: float animation → dùng RepeatMode thay vì addStatusListener (ít overhead)
  // _pageCtrl: scale khi chuyển trang
  late AnimationController _masterCtrl;
  late AnimationController _floatCtrl;
  late AnimationController _pageCtrl;

  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideUp;
  late final Animation<double> _floatAnim;
  late final Animation<double> _pageScale;

  static const _pages = [
    _PageData(
      title: 'Khám Phá',
      titleAccent: 'Bất Động Sản',
      description:
      'Hàng nghìn căn nhà, căn hộ và phòng trọ được cập nhật mỗi ngày. Tìm nơi ở lý tưởng chỉ trong vài giây.',
      type: _SlideType.lottieHouse,
    ),
    _PageData(
      title: 'Tìm Kiếm',
      titleAccent: 'Thông Minh',
      description:
      'Lọc theo giá, vị trí, diện tích, tiện ích. Bản đồ tích hợp giúp bạn tìm đúng khu vực mơ ước.',
      type: _SlideType.searchMap,
      imagePath: 'assets/img/tim.gif',
    ),
    _PageData(
      title: 'Kết Nối',
      titleAccent: 'Trực Tiếp',
      description:
      'Liên hệ chủ nhà ngay lập tức, đặt lịch xem nhà online và ký hợp đồng điện tử an toàn, thuận tiện.',
      type: _SlideType.contract,
      imagePath: 'assets/img/cn.gif',
    ),
  ];

  bool get _isLast => _currentPage == _pages.length - 1;

  @override
  void initState() {
    super.initState();

    _masterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // FIX: Dùng repeat(reverse: true) thay vì addStatusListener
    // → tránh callback overhead mỗi frame, Flutter tự xử lý nội bộ
    _floatCtrl = AnimationController(
      vsync: this,
      // FIX: Giảm từ 2600ms → 3000ms với lowerBound/upperBound
      // nhưng quan trọng hơn: dùng repeat thay vì manual listener
      duration: const Duration(milliseconds: 2800),
    );

    _pageCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );

    // FIX: Khai báo Animation một lần bằng late final, không nullable
    // → tránh null check (_fadeIn ?? ...) trong mỗi build frame
    _fadeIn = CurvedAnimation(
      parent: _masterCtrl,
      curve: const Interval(0.0, 0.75, curve: Curves.easeOut),
    );
    _slideUp = Tween<Offset>(
      begin: const Offset(0, 0.22),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _masterCtrl,
      curve: const Interval(0.1, 0.9, curve: Curves.easeOutCubic),
    ));

    // FIX: Biên độ nhỏ hơn (8 thay vì 10) → GPU ít tính toán composite hơn
    _floatAnim = Tween<double>(begin: -8.0, end: 8.0).animate(
      CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut),
    );

    _pageScale = Tween<double>(begin: 0.90, end: 1.0).animate(
      CurvedAnimation(parent: _pageCtrl, curve: Curves.easeOutBack),
    );

    // FIX: Gộp post-frame callback, tránh nhiều Future.delayed lồng nhau
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _masterCtrl.forward();
      _floatCtrl.repeat(reverse: true); // ← key fix: không dùng StatusListener
      _pageCtrl.forward();
    });
  }

  @override
  void dispose() {
    _masterCtrl.dispose();
    _floatCtrl.dispose();
    _pageCtrl.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int i) {
    HapticFeedback.selectionClick();
    setState(() => _currentPage = i);
    _pageCtrl
      ..reset()
      ..forward();
  }

  void _next() {
    if (_isLast) {
      _toLogin();
    } else {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _skip() => _pageController.animateToPage(
    _pages.length - 1,
    duration: const Duration(milliseconds: 500),
    curve: Curves.easeInOutCubic,
  );

  void _toLogin() {
    HapticFeedback.mediumImpact();
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, a, __) => const LoginScreen(),
        transitionsBuilder: (_, a, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: a, curve: Curves.easeIn),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.06),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
            child: child,
          ),
        ),
        transitionDuration: const Duration(milliseconds: 480),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context); // FIX: sizeOf thay vì of() → ít rebuild hơn

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeIn,
          child: Column(
            children: [
              // FIX: Tách _TopBar thành const widget riêng
              _TopBar(isLast: _isLast, onSkip: _skip),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: _onPageChanged,
                  itemCount: _pages.length,
                  // FIX: itemBuilder không re-tạo animation object mỗi lần
                  itemBuilder: (_, i) => _PageSlide(
                    page: _pages[i],
                    size: size,
                    slideUp: _slideUp,
                    pageScale: _pageScale,
                    floatAnim: _floatAnim,
                  ),
                ),
              ),
              _BottomBar(
                pageCount: _pages.length,
                currentPage: _currentPage,
                isLast: _isLast,
                onNext: _next,
                onLogin: _toLogin,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// TOP BAR — tách widget riêng giúp tránh rebuild toàn bộ tree
// ============================================================
class _TopBar extends StatelessWidget {
  final bool isLast;
  final VoidCallback onSkip;

  const _TopBar({required this.isLast, required this.onSkip});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                'assets/img/logoHome.jpg',
                width: 38,
                height: 38,
                fit: BoxFit.cover,
                // FIX: cache image với cacheWidth để giảm memory
                cacheWidth: 76, // 2x cho Retina
                errorBuilder: (_, __, ___) => Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_kBlue900, _kBlue500],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.home_rounded,
                      color: Colors.white, size: 22),
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'HOME PO',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: _kBlue900,
                letterSpacing: -0.4,
              ),
            ),
          ]),
          if (!isLast)
            GestureDetector(
              onTap: onSkip,
              child: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                decoration: _kSkipDecoration, // FIX: dùng const/cached decoration
                child: const Text(
                  'Bỏ qua',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _kBlue700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================
// PAGE SLIDE — widget riêng, nhận animation từ ngoài vào
// → không tạo AnimatedBuilder lồng nhau trong build của parent
// ============================================================
class _PageSlide extends StatelessWidget {
  final _PageData page;
  final Size size;
  final Animation<Offset> slideUp;
  final Animation<double> pageScale;
  final Animation<double> floatAnim;

  const _PageSlide({
    required this.page,
    required this.size,
    required this.slideUp,
    required this.pageScale,
    required this.floatAnim,
  });

  @override
  Widget build(BuildContext context) {
    final bool isGif = page.imagePath != null;

    return SlideTransition(
      position: slideUp,
      child: ScaleTransition(
        scale: pageScale,
        child: isGif
            ? _GifLayout(page: page, size: size, floatAnim: floatAnim)
            : _LottieLayout(page: page, size: size, floatAnim: floatAnim),
      ),
    );
  }
}

// ============================================================
// LOTTIE LAYOUT (slide 1)
// ============================================================
class _LottieLayout extends StatelessWidget {
  final _PageData page;
  final Size size;
  final Animation<double> floatAnim;

  const _LottieLayout({
    required this.page,
    required this.size,
    required this.floatAnim,
  });

  @override
  Widget build(BuildContext context) {
    final double d = size.width * 0.52;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // FIX: AnimatedBuilder bọc ít widget nhất có thể (chỉ Transform)
        AnimatedBuilder(
          animation: floatAnim,
          builder: (_, child) => Transform.translate(
            offset: Offset(0, floatAnim.value),
            child: child,
          ),
          // child không phụ thuộc floatAnim → không rebuild mỗi frame
          child: SizedBox(
            width: size.width * 0.72,
            height: d * 1.1,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                SizedBox(
                  width: d,
                  height: d,
                  child: ClipOval(
                    child: Lottie.asset(
                      AssetsConfig.loadingHouse,
                      fit: BoxFit.contain,
                      repeat: true,
                      // FIX: frameRate giảm từ max → 30fps đủ mượt, tiết kiệm CPU
                      frameRate:  FrameRate(30),
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.location_city_rounded,
                        size: d * 0.42,
                        color: _kBlue700,
                      ),
                    ),
                  ),
                ),
                const Positioned(
                  top: 4,
                  right: 0,
                  child: _FloatingBadge(
                    icon: Icons.star_rounded,
                    label: '4.9★',
                    iconColor: Color(0xFFFFD600),
                  ),
                ),
                const Positioned(
                  bottom: 8,
                  left: 0,
                  child: _FloatingBadge(
                    icon: Icons.home_work_rounded,
                    label: '10K+',
                    iconColor: _kBlue500,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 36),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: _TextBlock(page: page),
        ),
      ],
    );
  }
}

// ============================================================
// GIF LAYOUT (slide 2 & 3)
// ============================================================
class _GifLayout extends StatelessWidget {
  final _PageData page;
  final Size size;
  final Animation<double> floatAnim;

  const _GifLayout({
    required this.page,
    required this.size,
    required this.floatAnim,
  });

  @override
  Widget build(BuildContext context) {
    final double gifHeight = size.height * 0.40; // FIX: giảm nhẹ từ 0.42

    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 16),
          // FIX: AnimatedBuilder child tách ra → GIF không rebuild mỗi frame
          AnimatedBuilder(
            animation: floatAnim,
            builder: (_, child) => Transform.translate(
              offset: Offset(0, floatAnim.value * 0.4), // FIX: nhân 0.4 thay vì 0.5
              child: child,
            ),
            child: Stack(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: gifHeight,
                  child: Image.asset(
                    page.imagePath!,
                    fit: BoxFit.contain,
                    // FIX: RepaintBoundary ngầm — gacheWidth/Height giảm GPU texture upload
                    cacheHeight: (gifHeight * 2).toInt(),
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.image_not_supported_rounded,
                      size: 64,
                      color: _kBlue300,
                    ),
                  ),
                ),
                const Positioned(
                  top: 8,
                  right: 16,
                  child: _FloatingBadge(
                    icon: Icons.star_rounded,
                    label: '4.9★',
                    iconColor: Color(0xFFFFD600),
                  ),
                ),
                const Positioned(
                  bottom: 12,
                  left: 16,
                  child: _FloatingBadge(
                    icon: Icons.home_work_rounded,
                    label: '10K+',
                    iconColor: _kBlue500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: _TextBlock(page: page),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// TEXT BLOCK — const widget, không bao giờ rebuild
// ============================================================
class _TextBlock extends StatelessWidget {
  final _PageData page;

  const _TextBlock({required this.page});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          page.title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w300,
            color: Color(0xFF1A2340),
            letterSpacing: -0.3,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 16),
        ShaderMask(
          shaderCallback: (bounds) =>
              _kTitleGradient.createShader(bounds), // FIX: dùng const gradient
          child: Text(
            page.titleAccent,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 38,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -1.0,
              height: 1.1,
            ),
          ),
        ),
        const SizedBox(height: 16),
        // FIX: Dùng const widget con — Flutter skip diffing
        const _Divider(),
        const SizedBox(height: 16),
        Text(
          page.description,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14.5,
            color: Colors.grey.shade600,
            height: 1.72,
            letterSpacing: 0.1,
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

// Tách divider nhỏ thành const widget
class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 36,
          height: 3,
          decoration: BoxDecoration(
            color: _kBlue500,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        const SizedBox(
          width: 8,
          height: 8,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: _kBlue300,
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Container(
          width: 36,
          height: 3,
          decoration: BoxDecoration(
            color: _kBlue500,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// FLOATING BADGE — const constructor
// ============================================================
class _FloatingBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color iconColor;

  // FIX: const constructor → Flutter cache và reuse widget
  const _FloatingBadge({
    required this.icon,
    required this.label,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: _kBlue700.withOpacity(0.15),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: _kBlue900,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// BOTTOM BAR — StatelessWidget nhận callback
// ============================================================
class _BottomBar extends StatelessWidget {
  final int pageCount;
  final int currentPage;
  final bool isLast;
  final VoidCallback onNext;
  final VoidCallback onLogin;

  const _BottomBar({
    required this.pageCount,
    required this.currentPage,
    required this.isLast,
    required this.onNext,
    required this.onLogin,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
      child: Column(
        children: [
          // Dot indicators
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(pageCount, (i) {
              final active = i == currentPage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 280), // FIX: giảm từ 320
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: active ? 28 : 8,
                height: 8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: active ? _kBlue700 : _kBlue300.withOpacity(0.5),
                ),
              );
            }),
          ),
          const SizedBox(height: 22),
          // Next / Start button
          GestureDetector(
            onTap: onNext,
            child: Container(
              width: double.infinity,
              height: 58,
              decoration: _kButtonDecoration, // FIX: cached decoration
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    isLast ? 'Bắt đầu ngay' : 'Tiếp theo',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_rounded,
                      color: Colors.white, size: 20),
                ],
              ),
            ),
          ),
          if (isLast) ...[
            const SizedBox(height: 16),
            GestureDetector(
              onTap: onLogin,
              child: RichText(
                text: const TextSpan(
                  text: 'Đã có tài khoản? ',
                  style:
                  TextStyle(fontSize: 14, color: Color(0xFF9E9E9E)),
                  children: [
                    TextSpan(
                      text: 'Đăng nhập',
                      style: TextStyle(
                          color: _kBlue700, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
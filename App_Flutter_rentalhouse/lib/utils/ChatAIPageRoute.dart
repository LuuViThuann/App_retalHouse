import 'package:flutter/material.dart';

/// ════════════════════════════════════════════════════════════
/// CHAT AI PAGE ROUTE — Hiệu ứng chuyển trang ổn định
/// ════════════════════════════════════════════════════════════
///
/// Cách dùng:
///   Navigator.push(context, ChatAIPageRoute(page: const ChatAIPage()));
///
/// ════════════════════════════════════════════════════════════

class ChatAIPageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  ChatAIPageRoute({required this.page})
      : super(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionDuration: const Duration(milliseconds: 480),
    reverseTransitionDuration: const Duration(milliseconds: 360),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return _ChatAITransition(
        animation: animation,
        secondaryAnimation: secondaryAnimation,
        child: child,
      );
    },
  );
}

class _ChatAITransition extends StatelessWidget {
  final Animation<double> animation;
  final Animation<double> secondaryAnimation;
  final Widget child;

  const _ChatAITransition({
    required this.animation,
    required this.secondaryAnimation,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    // ── TRANG MỚI VÀO ───────────────────────────────────────

    // Slide từ dưới lên nhẹ
    final slideIn = Tween<Offset>(
      begin: const Offset(0.0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
    ));

    // Scale từ 0.94 → 1.0
    final scaleIn = Tween<double>(
      begin: 0.94,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
    ));

    // Fade in
    final fadeIn = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
    );

    // ── TRANG CŨ BỊ ĐÈ ──────────────────────────────────────

    // Scale trang cũ thu nhỏ nhẹ
    final scaleOut = Tween<double>(
      begin: 1.0,
      end: 0.96,
    ).animate(CurvedAnimation(
      parent: secondaryAnimation,
      curve: Curves.easeInOut,
    ));

    // Mờ trang cũ
    final fadeOut = Tween<double>(
      begin: 1.0,
      end: 0.6,
    ).animate(CurvedAnimation(
      parent: secondaryAnimation,
      curve: Curves.easeIn,
    ));

    // ── SHIMMER OVERLAY ──────────────────────────────────────
    final shimmerOpacity = Tween<double>(
      begin: 0.14,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: animation,
      curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
    ));

    return AnimatedBuilder(
      animation: Listenable.merge([animation, secondaryAnimation]),
      builder: (context, _) {
        // Trang cũ: scale + fade khi bị đè
        final Widget scaledBackground = Transform.scale(
          scale: scaleOut.value,
          child: Opacity(
            opacity: fadeOut.value,
            child: Container(), // placeholder — trang cũ tự render bởi Flutter
          ),
        );

        // Trang mới: slide + scale + fade
        return Transform.scale(
          scale: scaleOut.value,
          child: Opacity(
            opacity: fadeOut.value,
            child: FadeTransition(
              opacity: fadeIn,
              child: SlideTransition(
                position: slideIn,
                child: ScaleTransition(
                  scale: scaleIn,
                  child: Stack(
                    children: [
                      // Nội dung trang
                      child,

                      // Shimmer xanh nhẹ từ top khi mở
                      Positioned.fill(
                        child: IgnorePointer(
                          child: AnimatedBuilder(
                            animation: shimmerOpacity,
                            builder: (_, __) => Opacity(
                              opacity: shimmerOpacity.value,
                              child: Container(
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Color(0xFF1E40AF),
                                      Colors.transparent,
                                    ],
                                    stops: [0.0, 0.5],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
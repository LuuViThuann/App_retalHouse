import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/config/loading.dart';
import 'package:provider/provider.dart';
import 'package:lottie/lottie.dart';
import '../../viewmodels/vm_rental.dart';

// ================================================================
//  ENTRY POINT
// ================================================================

void showAIExplanationDialog({
  required BuildContext context,
  required String userId,
  required String rentalId,
  required String rentalTitle,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black26,
    builder: (_) => ChangeNotifierProvider.value(
      value: Provider.of<RentalViewModel>(context, listen: false),
      child: AIExplanationSheet(
        userId: userId,
        rentalId: rentalId,
        rentalTitle: rentalTitle,
      ),
    ),
  );
}

// ================================================================
//  BOTTOM SHEET ROOT
// ================================================================

class AIExplanationSheet extends StatefulWidget {
  final String userId;
  final String rentalId;
  final String rentalTitle;

  const AIExplanationSheet({
    super.key,
    required this.userId,
    required this.rentalId,
    required this.rentalTitle,
  });

  @override
  State<AIExplanationSheet> createState() => _AIExplanationSheetState();
}

class _AIExplanationSheetState extends State<AIExplanationSheet>
    with TickerProviderStateMixin {
  late final AnimationController _entryCtrl;
  late final AnimationController _barCtrl;
  late final AnimationController _pulseCtrl;

  late final Animation<double> _slideAnim;
  late final Animation<double> _fadeAnim;

  // ── Light Design Tokens ──────────────────────────────────────
  static const _bg         = Color(0xFFF8FAFF);
  static const _surface    = Colors.white;
  static const _card       = Color(0xFFF1F5FB);
  static const _border     = Color(0xFFE2E8F4);
  static const _borderSoft = Color(0xFFEDF1FA);
  static const _textHi     = Color(0xFF0F172A);
  static const _textMid    = Color(0xFF475569);
  static const _textLo     = Color(0xFFADB8CC);
  static const _purple     = Color(0xFF7C3AED);
  static const _purpleLight = Color(0xFFEDE9FE);
  static const _amber      = Color(0xFFD97706);
  static const _amberLight = Color(0xFFFEF3C7);
  static const _emerald    = Color(0xFF059669);
  static const _emeraldLight = Color(0xFFD1FAE5);
  static const _rose       = Color(0xFFDC2626);
  static const _roseLight  = Color(0xFFFEE2E2);
  static const _blue       = Color(0xFF2563EB);
  static const _blueLight  = Color(0xFFDBEAFE);
  static const _cyan       = Color(0xFF0891B2);
  static const _cyanLight  = Color(0xFFCFFAFE);

  @override
  void initState() {
    super.initState();

    _entryCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 420));
    _barCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000));
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2000))
      ..repeat(reverse: true);

    _slideAnim = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic);
    _fadeAnim  = CurvedAnimation(
        parent: _entryCtrl,
        curve: const Interval(0, 0.6, curve: Curves.easeOut));

    _entryCtrl.forward();

    Future.microtask(() {
      if (!mounted) return;
      Provider.of<RentalViewModel>(context, listen: false).fetchAIExplanation(
        userId: widget.userId,
        rentalId: widget.rentalId,
      );
    });

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _barCtrl.forward();
    });
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _barCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ──────────────────────────────────────────────────

  double? _safe(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  String _confidenceLabel(double v) {
    if (v >= 0.80) return 'Rất phù hợp';
    if (v >= 0.60) return 'Khá phù hợp';
    if (v >= 0.40) return 'Có thể phù hợp';
    return 'Tham khảo thêm';
  }

  Color _confidenceColor(double v) {
    if (v >= 0.75) return _emerald;
    if (v >= 0.55) return _amber;
    return _rose;
  }

  Color _confidenceBgColor(double v) {
    if (v >= 0.75) return _emeraldLight;
    if (v >= 0.55) return _amberLight;
    return _roseLight;
  }

  List<Color> _confidenceGradient(double v) {
    if (v >= 0.80) return [const Color(0xFF059669), const Color(0xFF34D399)];
    if (v >= 0.60) return [const Color(0xFF2563EB), const Color(0xFF60A5FA)];
    if (v >= 0.40) return [const Color(0xFFD97706), const Color(0xFFFBBF24)];
    return [const Color(0xFFDC2626), const Color(0xFFF87171)];
  }

  // ── Build ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return AnimatedBuilder(
      animation: _slideAnim,
      builder: (_, __) => FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: Tween<Offset>(
              begin: const Offset(0, .10), end: Offset.zero)
              .animate(_slideAnim),
          child: Container(
            constraints: BoxConstraints(maxHeight: mq.size.height * 0.92),
            decoration: const BoxDecoration(
              color: _bg,
              borderRadius:
              BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                  color: Color(0x18000000),
                  blurRadius: 32,
                  offset: Offset(0, -6),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _handle(),
                _header(),
                Container(height: 1, color: _borderSoft),
                Flexible(
                  child: Consumer<RentalViewModel>(
                    builder: (ctx, vm, _) {
                      if (vm.isLoadingExplanation) return _loadingState();
                      if (vm.explanationError != null)
                        return _errorState(vm.explanationError!, vm);
                      if (vm.currentExplanation != null)
                        return _body(vm.currentExplanation!);
                      return _emptyState();
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Handle ───────────────────────────────────────────────────

  Widget _handle() => Padding(
    padding: const EdgeInsets.only(top: 10, bottom: 4),
    child: Container(
      width: 36,
      height: 4,
      decoration: BoxDecoration(
        color: _border,
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );

  // ── Header ───────────────────────────────────────────────────

  Widget _header() => Padding(
    padding: const EdgeInsets.fromLTRB(18, 10, 14, 14),
    child: Row(
      children: [
        // Animated icon badge
        AnimatedBuilder(
          animation: _pulseCtrl,
          builder: (_, __) => Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1D4ED8), Color(0xFF60A5FA)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: _purple.withOpacity(
                      0.18 + _pulseCtrl.value * 0.12),
                  blurRadius: 12 + _pulseCtrl.value * 5,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.psychology_outlined,
                color: Colors.white, size: 22),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tư vấn từ trợ lý AI',
                style: TextStyle(
                  color: _textHi,
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                widget.rentalTitle,
                style: const TextStyle(color: _textMid, fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: _border),
            ),
            child: const Icon(Icons.close_rounded,
                color: _textMid, size: 15),
          ),
        ),
      ],
    ),
  );

  // ── States ───────────────────────────────────────────────────

  Widget _loadingState() => SizedBox(
    height: 220,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Lottie.asset(AssetsConfig.loadingLottie,
            width: 70, height: 70, fit: BoxFit.fill),
        const SizedBox(height: 12),
        const Text('Đang phân tích...',
            style: TextStyle(
                color: _textMid,
                fontSize: 13,
                fontWeight: FontWeight.w500)),
      ],
    ),
  );

  Widget _errorState(String error, RentalViewModel vm) => SizedBox(
    height: 240,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: _roseLight, shape: BoxShape.circle),
          child: const Icon(Icons.error_outline,
              color: _rose, size: 26),
        ),
        const SizedBox(height: 14),
        const Text('Không thể tải giải thích',
            style: TextStyle(
                color: _rose,
                fontSize: 14,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(error,
              style:
              const TextStyle(color: _textMid, fontSize: 12),
              textAlign: TextAlign.center),
        ),
        const SizedBox(height: 18),
        GestureDetector(
          onTap: () => vm.fetchAIExplanation(
              userId: widget.userId, rentalId: widget.rentalId),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: _surface,
              border: Border.all(color: _border),
              borderRadius: BorderRadius.circular(10),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x0A000000),
                    blurRadius: 6,
                    offset: Offset(0, 2))
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.refresh_rounded, color: _textMid, size: 15),
                SizedBox(width: 6),
                Text('Thử lại',
                    style: TextStyle(
                        color: _textMid,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Widget _emptyState() => SizedBox(
    height: 180,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.info_outline_rounded, size: 30, color: _textLo),
        const SizedBox(height: 12),
        const Text('Chưa có giải thích',
            style: TextStyle(color: _textMid, fontSize: 13)),
      ],
    ),
  );

  // ── Main Body ────────────────────────────────────────────────

  Widget _body(AIExplanation explanation) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
          16, 18, 16, MediaQuery.of(context).viewInsets.bottom + 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _confidenceCard(explanation),
          const SizedBox(height: 14),
          _quickSummaryCard(explanation),
          if (explanation.explanation?['insights'] != null) ...[
            const SizedBox(height: 14),
            _insightsSection(explanation.explanation!['insights']),
          ],
          const SizedBox(height: 14),
          _reasonsSection(explanation),
          const SizedBox(height: 20),
          _closeButton(),
        ],
      ),
    );
  }

  // ── Confidence Card ──────────────────────────────────────────

  Widget _confidenceCard(AIExplanation explanation) {
    final confidence =
    (_safe(explanation.scores['confidence']) ?? 0.5).clamp(0.0, 1.0);
    final contentScore =
    (_safe(explanation.scores['content_score']) ?? 0.0).clamp(0.0, 1.0);
    final cfScore =
    (_safe(explanation.scores['cf_score']) ?? 0.0).clamp(0.0, 1.0);
    final popularityScore =
    (_safe(explanation.scores['popularity_score']) ?? 0.0).clamp(0.0, 1.0);

    final color   = _confidenceColor(confidence);
    final bgColor = _confidenceBgColor(confidence);
    final label   = _confidenceLabel(confidence);
    final pct     = (confidence * 100).round();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
              color: Color(0x08000000),
              blurRadius: 16,
              offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          // ── Top row: ring + text ──
          Row(
            children: [
              SizedBox(
                width: 72,
                height: 72,
                child: AnimatedBuilder(
                  animation: _barCtrl,
                  builder: (_, __) => CustomPaint(
                    painter: _RingPainter(
                      progress: confidence * _barCtrl.value,
                      color: color,
                      track: _border,
                    ),
                    child: Center(
                      child: Text(
                        '$pct%',
                        style: TextStyle(
                            color: color,
                            fontSize: 17,
                            fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Pill label
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: ShaderMask(
                        shaderCallback: (r) => LinearGradient(
                            colors: _confidenceGradient(confidence))
                            .createShader(r),
                        child: Text(
                          label,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                    const SizedBox(height: 9),
                    AnimatedBuilder(
                      animation: _barCtrl,
                      builder: (_, __) => _ProgressBar(
                        value: confidence * _barCtrl.value,
                        color: color,
                        height: 5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Dựa trên sở thích, lịch sử tìm kiếm và cộng đồng người dùng',
                      style: TextStyle(
                          color: _textMid, fontSize: 11, height: 1.55),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),
          Container(height: 1, color: _borderSoft),
          const SizedBox(height: 14),

          // ── Score rows ──
          _scoreRow(
            icon: Icons.favorite_rounded,
            color: _purple,
            bgColor: _purpleLight,
            label: 'Phù hợp sở thích',
            value: contentScore > 0
                ? contentScore
                : (_safe(explanation.scores['preference_score']) ?? 0.5)
                .clamp(0.0, 1.0),
          ),
          const SizedBox(height: 10),
          _scoreRow(
            icon: Icons.people_alt_rounded,
            color: _amber,
            bgColor: _amberLight,
            label: 'Người dùng tương tự',
            value: cfScore > 0
                ? cfScore
                : ((_safe(explanation.scores['collaborative_score']) ?? 0.0) /
                2.0)
                .clamp(0.0, 1.0),
          ),
          const SizedBox(height: 10),
          _scoreRow(
            icon: Icons.trending_up_rounded,
            color: _emerald,
            bgColor: _emeraldLight,
            label: 'Độ phổ biến',
            value: popularityScore > 0
                ? popularityScore
                : ((_safe(explanation.scores['confidence']) ?? 0.5) * 0.6)
                .clamp(0.0, 1.0),
          ),
        ],
      ),
    );
  }

  Widget _scoreRow({
    required IconData icon,
    required Color color,
    required Color bgColor,
    required String label,
    required double value,
  }) {
    final safe = value.clamp(0.0, 1.0);
    final pct  = (safe * 100).round();
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 17),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: _textHi,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 5),
              AnimatedBuilder(
                animation: _barCtrl,
                builder: (_, __) => _ProgressBar(
                  value: safe * _barCtrl.value,
                  color: color,
                  height: 4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
              color: bgColor, borderRadius: BorderRadius.circular(7)),
          child: Text('$pct%',
              style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }

  // ── Quick Summary ────────────────────────────────────────────

  Widget _quickSummaryCard(AIExplanation explanation) {
    final highlights = <({String text, IconData icon, Color color, Color bg})>[];

    explanation.reasons.forEach((_, value) {
      if (value.contains('RẺ HƠN') || value.contains('TIẾT KIỆM'))
        highlights.add((
        text: 'Giá tốt',
        icon: Icons.local_offer_rounded,
        color: _purple,
        bg: _purpleLight
        ));
      if (value.contains('gần') || value.contains('km'))
        highlights.add((
        text: 'Vị trí thuận tiện',
        icon: Icons.location_on_rounded,
        color: _amber,
        bg: _amberLight
        ));
      if (value.contains('YÊU THÍCH') || value.contains('sở thích'))
        highlights.add((
        text: 'Đúng sở thích',
        icon: Icons.favorite_rounded,
        color: _rose,
        bg: _roseLight
        ));
      if (value.contains('TIỆN ÍCH') || value.contains('MOVE-IN'))
        highlights.add((
        text: 'Đầy đủ tiện nghi',
        icon: Icons.auto_awesome_rounded,
        color: _cyan,
        bg: _cyanLight
        ));
    });

    if (highlights.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('Tại sao phù hợp?'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: highlights.take(4).map((h) {
            return Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: h.bg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(h.icon, size: 13, color: h.color),
                  const SizedBox(width: 5),
                  Text(h.text,
                      style: TextStyle(
                          color: h.color,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ── Insights ─────────────────────────────────────────────────

  Widget _insightsSection(List<dynamic> insights) {
    if (insights.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('Phân Tích Thú Vị'),
        const SizedBox(height: 10),
        ...insights.map((insight) {
          final icon        = insight['icon'] ?? '✨';
          final title       = insight['title'] ?? '';
          final description = insight['description'] ?? '';
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: _emeraldLight,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: _emerald.withOpacity(.18)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(icon, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: _emerald)),
                      const SizedBox(height: 3),
                      Text(description,
                          style: TextStyle(
                              fontSize: 11.5,
                              color: _emerald.withOpacity(.75),
                              height: 1.5)),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  // ── Reasons ──────────────────────────────────────────────────

  Widget _reasonsSection(AIExplanation explanation) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('Lý Do Gợi Ý'),
        const SizedBox(height: 10),
        if (explanation.reasons.isEmpty)
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _border),
            ),
            child: const Text(
              'Bài viết này phù hợp với sở thích của bạn',
              style: TextStyle(fontSize: 12.5, color: _textMid),
            ),
          )
        else
          ...explanation.reasons.entries.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _reasonItem(e.key, e.value),
          )),
      ],
    );
  }

  Widget _reasonItem(String title, String description) {
    IconData icon  = Icons.check_circle_outline_rounded;
    Color    color = _emerald;
    Color    bg    = _emeraldLight;

    if (description.contains('TOP') || description.contains('YÊU THÍCH NHẤT')) {
      icon = Icons.stars_rounded;   color = _amber;  bg = _amberLight;
    } else if (description.contains('km') || description.contains('gần')) {
      icon = Icons.location_on_rounded;
      color = const Color(0xFFEA580C); bg = const Color(0xFFFFEDD5);
    } else if (description.contains('RẺ HƠN') ||
        description.contains('tiết kiệm')) {
      icon = Icons.monetization_on_rounded; color = _emerald; bg = _emeraldLight;
    } else if (description.contains('chất lượng')) {
      icon = Icons.diamond_rounded; color = _purple; bg = _purpleLight;
    } else if (description.contains('loại')) {
      icon = Icons.home_rounded;    color = _blue;   bg = _blueLight;
    } else if (description.contains('TIỆN ÍCH') ||
        description.contains('MOVE-IN')) {
      icon = Icons.auto_awesome_rounded; color = _cyan; bg = _cyanLight;
    }

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
              color: Color(0x06000000),
              blurRadius: 8,
              offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
                color: bg, borderRadius: BorderRadius.circular(9)),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(child: _highlightText(description, color)),
        ],
      ),
    );
  }

  Widget _highlightText(String text, Color highlight) {
    const keywords = [
      'RẺ HƠN', 'TIẾT KIỆM', 'TOP', 'YÊU THÍCH NHẤT',
      'MOVE-IN READY', 'ĐẦY ĐỦ TIỆN ÍCH', 'ĐỘ TIN CẬY CAO',
    ];

    final spans = <TextSpan>[];
    String remaining = text;

    for (final kw in keywords) {
      if (!remaining.contains(kw)) continue;
      final parts = remaining.split(kw);
      for (int i = 0; i < parts.length; i++) {
        if (i > 0) {
          spans.add(TextSpan(
              text: kw,
              style: TextStyle(
                  fontSize: 12.5,
                  color: highlight,
                  fontWeight: FontWeight.w700)));
        }
        if (parts[i].isNotEmpty) {
          spans.add(TextSpan(
              text: parts[i],
              style: const TextStyle(
                  fontSize: 12.5, color: _textMid, height: 1.55)));
        }
      }
      return RichText(text: TextSpan(children: spans));
    }

    return Text(text,
        style: const TextStyle(
            fontSize: 12.5, color: _textMid, height: 1.55));
  }

  // ── Close Button ─────────────────────────────────────────────

  Widget _closeButton() => SizedBox(
    width: double.infinity,
    child: GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: _surface,
          border: Border.all(color: _border),
          borderRadius: BorderRadius.circular(13),
          boxShadow: const [
            BoxShadow(
                color: Color(0x08000000),
                blurRadius: 8,
                offset: Offset(0, 2)),
          ],
        ),
        child: const Text(
          'Đóng',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: _textMid,
              fontSize: 14,
              fontWeight: FontWeight.w600),
        ),
      ),
    ),
  );
}

// ================================================================
//  SHARED SMALL WIDGETS
// ================================================================

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
        color: Color(0xFF0F172A),
        fontSize: 13.5,
        fontWeight: FontWeight.w700,
        letterSpacing: .1),
  );
}

class _ProgressBar extends StatelessWidget {
  final double value;
  final Color color;
  final double height;
  const _ProgressBar(
      {required this.value, required this.color, required this.height});

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Container(
        height: height,
        decoration: BoxDecoration(
            color: const Color(0xFFE2E8F4),
            borderRadius: BorderRadius.circular(height)),
      ),
      FractionallySizedBox(
        widthFactor: value.clamp(0.0, 1.0),
        child: Container(
          height: height,
          decoration: BoxDecoration(
            gradient:
            LinearGradient(colors: [color.withOpacity(.65), color]),
            borderRadius: BorderRadius.circular(height),
            boxShadow: [
              BoxShadow(
                  color: color.withOpacity(.25),
                  blurRadius: 4,
                  offset: const Offset(0, 1))
            ],
          ),
        ),
      ),
    ]);
  }
}

// ================================================================
//  RING PROGRESS PAINTER
// ================================================================

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color track;
  const _RingPainter(
      {required this.progress, required this.color, required this.track});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r  = math.min(cx, cy) - 5;

    canvas.drawCircle(
        Offset(cx, cy),
        r,
        Paint()
          ..color = const Color(0xFFE2E8F4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5.5);

    canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        -math.pi / 2,
        2 * math.pi * progress.clamp(0.0, 1.0),
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5.5
          ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color;
}
// ============================================================
// FILE: Widgets/Detail/MapToolbar.dart
//
// Thay thế toàn bộ _buildTopLeftControls() trong RentalMapView
//
// THIẾT KẾ:
// - Thanh icon dọc nhỏ gọn bên trái (chỉ icon + badge)
// - Khi tap 1 nút → mở ActionSheet nhỏ bên phải nút đó
// - Chip trạng thái nổi phía trên badge đếm
// ============================================================

import 'package:flutter/material.dart';

// ════════════════════════════════════════════════════════════
// MODEL: Định nghĩa từng tool trong toolbar
// ════════════════════════════════════════════════════════════
class MapToolItem {
  final String id;
  final IconData icon;
  final IconData activeIcon;
  final Widget? iconWidget;        // Custom widget thay icon (ưu tiên hơn icon)
  final Widget? activeIconWidget;  // Custom widget khi active
  final String label;
  final Color activeColor;
  final bool isActive;
  final String? badgeText; // Số lượng, trạng thái ngắn
  final Future<void> Function() onTap;
  final Future<void> Function()? onActiveTap; // Khi đang active, tap để tắt

  MapToolItem({
    required this.id,
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.activeColor,
    required this.isActive,
    required this.onTap,
    this.iconWidget,
    this.activeIconWidget,
    this.badgeText,
    this.onActiveTap,
  });
}

// ════════════════════════════════════════════════════════════
// WIDGET CHÍNH: MapToolbar
// ════════════════════════════════════════════════════════════
class MapToolbar extends StatefulWidget {
  final List<MapToolItem> tools;
  final bool visible;

  const MapToolbar({
    super.key,
    required this.tools,
    this.visible = true,
  });

  @override
  State<MapToolbar> createState() => _MapToolbarState();
}

class _MapToolbarState extends State<MapToolbar>
    with SingleTickerProviderStateMixin {
  String? _openTooltipId; // ID của tool đang mở tooltip
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    if (widget.visible) _animController.forward();
  }

  @override
  void didUpdateWidget(MapToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible != oldWidget.visible) {
      if (widget.visible) {
        _animController.forward();
      } else {
        _animController.reverse();
        _openTooltipId = null;
      }
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _handleToolTap(MapToolItem tool) async {
    // Nếu đang active → gọi onActiveTap hoặc onTap
    if (tool.isActive) {
      if (tool.onActiveTap != null) {
        await tool.onActiveTap!();
      } else {
        await tool.onTap();
      }
      setState(() => _openTooltipId = null);
      return;
    }

    // Hiện tooltip label 1.5s rồi tự ẩn
    setState(() => _openTooltipId = tool.id);
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted && _openTooltipId == tool.id) {
        setState(() => _openTooltipId = null);
      }
    });

    await tool.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(-0.4, 0),
          end: Offset.zero,
        ).animate(_fadeAnim),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: widget.tools.map((tool) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildToolButton(tool),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildToolButton(MapToolItem tool) {
    final bool showTooltip = _openTooltipId == tool.id && !tool.isActive;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // ── Icon Button ──────────────────────────────────────
        _ToolIconButton(
          tool: tool,
          onTap: () async => _handleToolTap(tool),
        ),

        // ── Label tooltip (hiện khi tap lần đầu) ────────────
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(-0.15, 0),
                end: Offset.zero,
              ).animate(anim),
              child: child,
            ),
          ),
          child: showTooltip
              ? Padding(
            key: ValueKey(tool.id),
            padding: const EdgeInsets.only(left: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.75),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                tool.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          )
              : const SizedBox.shrink(key: ValueKey('empty')),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════
// SUB-WIDGET: Icon button tròn
// ════════════════════════════════════════════════════════════
class _ToolIconButton extends StatefulWidget {
  final MapToolItem tool;
  final Future<void> Function() onTap;

  const _ToolIconButton({required this.tool, required this.onTap});

  @override
  State<_ToolIconButton> createState() => _ToolIconButtonState();
}

class _ToolIconButtonState extends State<_ToolIconButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.88).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  // Ưu tiên iconWidget nếu có, fallback về Icon thường
  Widget _buildIconChild(MapToolItem tool, bool active) {
    if (active && tool.activeIconWidget != null) {
      return SizedBox(
        key: const ValueKey(true),
        width: 44,
        height: 44,
        child: tool.activeIconWidget!,
      );
    }
    if (!active && tool.iconWidget != null) {
      return SizedBox(
        key: const ValueKey(false),
        width: 44,
        height: 44,
        child: tool.iconWidget!,
      );
    }
    return Icon(
      active ? tool.activeIcon : tool.icon,
      key: ValueKey(active),
      color: active ? Colors.white : Colors.grey.shade700,
      size: 20,
    );
  }

  // Kiểm tra tool có dùng custom image không
  bool get _hasCustomIcon =>
      widget.tool.iconWidget != null || widget.tool.activeIconWidget != null;

  @override
  Widget build(BuildContext context) {
    final tool = widget.tool;
    final bool active = tool.isActive;

    // Nếu có iconWidget → render ảnh trong container 44x44, không có nền
    if (_hasCustomIcon) {
      return GestureDetector(
        onTapDown: (_) => _pressController.forward(),
        onTapUp: (_) async {
          _pressController.reverse();
          await widget.onTap();
        },
        onTapCancel: () => _pressController.reverse(),
        child: ScaleTransition(
          scale: _scaleAnim,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _buildIconChild(tool, active),
                  ),
                ),
              ),

              // Badge số lượng
              if (active && tool.badgeText != null)
                Positioned(
                  top: -5,
                  right: -5,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: tool.activeColor, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Text(
                      tool.badgeText!,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: tool.activeColor,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    // Render thường với container nền
    return GestureDetector(
      onTapDown: (_) => _pressController.forward(),
      onTapUp: (_) async {
        _pressController.reverse();
        await widget.onTap();
      },
      onTapCancel: () => _pressController.reverse(),
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: active ? tool.activeColor : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: active
                    ? null
                    : Border.all(color: Colors.grey.shade200, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: active
                        ? tool.activeColor.withOpacity(0.35)
                        : Colors.black.withOpacity(0.12),
                    blurRadius: active ? 10 : 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _buildIconChild(tool, active),
                ),
              ),
            ),

            // ── Badge số lượng (khi active + có badgeText) ─
            if (active && tool.badgeText != null)
              Positioned(
                top: -5,
                right: -5,
                child: AnimatedScale(
                  scale: 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: tool.activeColor,
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Text(
                      tool.badgeText!,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: tool.activeColor,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
// WIDGET: LoadingToolButton — spinner thay icon khi đang load
// ════════════════════════════════════════════════════════════
class LoadingToolOverlay extends StatelessWidget {
  final bool isLoading;
  final Color color;

  const LoadingToolOverlay({
    super.key,
    required this.isLoading,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (!isLoading) return const SizedBox.shrink();
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ),
    );
  }
}
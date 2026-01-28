import 'package:flutter/material.dart';
import 'package:flutter_rentalhouse/config/loading.dart';
import 'package:provider/provider.dart';
import 'package:lottie/lottie.dart';
import '../../viewmodels/vm_rental.dart';


/// AI Explanation Dialog - Clean & Professional Design
class AIExplanationDialog extends StatefulWidget {
  final String userId;
  final String rentalId;
  final String rentalTitle;

  const AIExplanationDialog({
    super.key,
    required this.userId,
    required this.rentalId,
    required this.rentalTitle,
  });

  @override
  State<AIExplanationDialog> createState() => _AIExplanationDialogState();
}

class _AIExplanationDialogState extends State<AIExplanationDialog> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      Provider.of<RentalViewModel>(context, listen: false)
          .fetchAIExplanation(
        userId: widget.userId,
        rentalId: widget.rentalId,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RentalViewModel>(
      builder: (context, viewModel, _) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: Colors.white,
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.65,
              maxWidth: MediaQuery.of(context).size.width * 0.95,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ==================== HEADER ====================
                _buildHeader(),

                // ==================== CONTENT ====================
                Expanded(
                  child: SingleChildScrollView(
                    child: viewModel.isLoadingExplanation
                        ? _buildLoadingState()
                        : viewModel.explanationError != null
                        ? _buildErrorState(viewModel.explanationError!)
                        : viewModel.currentExplanation != null
                        ? _buildExplanationContent(
                        viewModel.currentExplanation!)
                        : _buildEmptyState(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ==================== HEADER ====================
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey[200]!, width: 1),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.psychology_outlined, color: Colors.blue[700], size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tư vấn từ trợ lý AI',
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Tại sao bài này phù hợp với bạn?',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.close, color: Colors.grey[600], size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  // ==================== LOADING STATE ====================
  Widget _buildLoadingState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Lottie.asset(
            AssetsConfig.loadingLottie,
            width: 80,
            height: 80,
            fit: BoxFit.fill,
          ),
          const SizedBox(height: 16),
          Text(
            'Đang phân tích...',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ==================== ERROR STATE ====================
  Widget _buildErrorState(String error) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, color: Colors.red[400], size: 32),
          const SizedBox(height: 12),
          Text(
            'Không thể tải giải thích',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.red[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () {
              Provider.of<RentalViewModel>(context, listen: false)
                  .fetchAIExplanation(
                userId: widget.userId,
                rentalId: widget.rentalId,
              );
            },
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Thử lại'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              foregroundColor: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== EMPTY STATE ====================
  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.info_outline, size: 28, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(
            'Chưa có giải thích',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== EXPLANATION CONTENT ====================
  Widget _buildExplanationContent(AIExplanation explanation) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // CONFIDENCE CARD
          _buildConfidenceCard(explanation),
          const SizedBox(height: 20),

          // QUICK SUMMARY
          _buildQuickSummaryCard(explanation),
          const SizedBox(height: 20),

          // INSIGHTS
          if (explanation.explanation?['insights'] != null)
            _buildInsightsSection(explanation.explanation!['insights']),

          if (explanation.explanation?['insights'] != null)
            const SizedBox(height: 20),

          // REASONS
          _buildReasons(explanation),
          const SizedBox(height: 20),

          // ACTION BUTTONS
          _buildActionButtons(),
        ],
      ),
    );
  }

  // ==================== CONFIDENCE CARD ====================
  Widget _buildConfidenceCard(AIExplanation explanation) {
    // 🔥 FIX: Confidence đã là 0-1 từ backend
    final confidence = _safeParseDouble(explanation.scores['confidence']) ?? 0.5;
    final confidencePercent = (confidence * 100).toStringAsFixed(0);

    // 🔥 ADD: Detailed confidence breakdown
    final contentScore = _safeParseDouble(explanation.scores['content_score']) ?? 0.0;
    final cfScore = _safeParseDouble(explanation.scores['cf_score']) ?? 0.0;
    final popularityScore = _safeParseDouble(explanation.scores['popularity_score']) ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[100]!),
      ),
      child: Column(
        children: [
          // Main confidence circle
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: _getConfidenceGradient(confidence),
                  ),
                ),
                child: Center(
                  child: Text(
                    confidencePercent,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getConfidenceText(confidence),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[800],
                      ),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: confidence,
                        minHeight: 4,
                        backgroundColor: Colors.blue[200],
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[700]!),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // 🔥 NEW: Score breakdown
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              children: [
                _buildScoreRow('Phù hợp sở thích', contentScore, Colors.purple),
                const SizedBox(height: 4),
                _buildScoreRow('Người dùng tương tự', cfScore, Colors.orange),
                const SizedBox(height: 4),
                _buildScoreRow('Độ phổ biến', popularityScore, Colors.green),
              ],
            ),
          ),
        ],
      ),
    );
  }

// Helper widget
  Widget _buildScoreRow(String label, double score, Color color) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey[700]),
          ),
        ),
        Expanded(
          flex: 2,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: score,
              minHeight: 3,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${(score * 100).toStringAsFixed(0)}%',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  // ==================== QUICK SUMMARY ====================
  Widget _buildQuickSummaryCard(AIExplanation explanation) {
    final reasons = explanation.reasons;

    final List<({String text, IconData icon, Color color})> highlights = [];
    reasons.forEach((key, value) {
      if (value.contains('RẺ HƠN') || value.contains('TIẾT KIỆM')) {
        highlights.add(
          (text: 'Giá tốt', icon: Icons.local_offer, color: Colors.purple),
        );
      }
      if (value.contains('gần') || value.contains('km')) {
        highlights.add(
          (text: 'Vị trí thuận tiện', icon: Icons.location_on, color: Colors.orange),
        );
      }
      if (value.contains('YÊU THÍCH') || value.contains('sở thích')) {
        highlights.add(
          (text: 'Đúng sở thích', icon: Icons.favorite, color: Colors.red),
        );
      }
      if (value.contains('TIỆN ÍCH') || value.contains('MOVE-IN')) {
        highlights.add(
          (text: 'Đầy đủ tiện nghi', icon: Icons.star, color: Colors.amber),
        );
      }
    });

    if (highlights.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tại sao phù hợp?',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: highlights.take(4).map((highlight) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: highlight.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: highlight.color.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    highlight.icon,
                    size: 14,
                    color: highlight.color,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    highlight.text,
                    style: TextStyle(
                      color: highlight.color,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ==================== INSIGHTS SECTION ====================
  Widget _buildInsightsSection(List<dynamic> insights) {
    if (insights.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Phân Tích Thú Vị',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 10),
        ...insights.map((insight) {
          final icon = insight['icon'] ?? '✨';
          final title = insight['title'] ?? '';
          final description = insight['description'] ?? '';

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.green[200]!),
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
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[800],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.green[700],
                        ),
                      ),
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

  // ==================== REASONS ====================
  Widget _buildReasons(AIExplanation explanation) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Lý Do Gợi Ý',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 10),
        if (explanation.reasons.isEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Text(
              'Bài viết này phù hợp với sở thích của bạn',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[700],
              ),
            ),
          )
        else
          ...explanation.reasons.entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _buildReasonItem(entry.key, entry.value),
            );
          }).toList(),
      ],
    );
  }

  Widget _buildReasonItem(String title, String description) {
    IconData iconData = Icons.check_circle_outline;
    Color iconColor = Colors.green[600]!;
    Color bgColor = Colors.green[50]!;

    if (description.contains('TOP') || description.contains('YÊU THÍCH NHẤT')) {
      iconData = Icons.stars_rounded;
      iconColor = Colors.amber[700]!;
      bgColor = Colors.amber[50]!;
    } else if (description.contains('km') || description.contains('gần')) {
      iconData = Icons.location_on_rounded;
      iconColor = Colors.orange[600]!;
      bgColor = Colors.orange[50]!;
    } else if (description.contains('RẺ HƠN') ||
        description.contains('tiết kiệm')) {
      iconData = Icons.monetization_on_rounded;
      iconColor = Colors.green[700]!;
      bgColor = Colors.green[50]!;
    } else if (description.contains('chất lượng')) {
      iconData = Icons.diamond_rounded;
      iconColor = Colors.purple[600]!;
      bgColor = Colors.purple[50]!;
    } else if (description.contains('loại')) {
      iconData = Icons.home_rounded;
      iconColor = Colors.blue[600]!;
      bgColor = Colors.blue[50]!;
    } else if (description.contains('TIỆN ÍCH') ||
        description.contains('MOVE-IN')) {
      iconData = Icons.auto_awesome_rounded;
      iconColor = Colors.amber[600]!;
      bgColor = Colors.amber[50]!;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: iconColor.withOpacity(0.2), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(iconData, color: iconColor, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: _buildHighlightedText(description, iconColor),
          ),
        ],
      ),
    );
  }

  Widget _buildHighlightedText(String text, Color highlightColor) {
    final keywords = [
      'RẺ HƠN',
      'TIẾT KIỆM',
      'TOP',
      'YÊU THÍCH NHẤT',
      'MOVE-IN READY',
      'ĐẦY ĐỦ TIỆN ÍCH',
      'ĐỘ TIN CẬY CAO'
    ];

    TextSpan buildTextSpan() {
      final List<TextSpan> spans = [];
      String remaining = text;

      for (final keyword in keywords) {
        if (remaining.contains(keyword)) {
          final parts = remaining.split(keyword);
          for (int i = 0; i < parts.length; i++) {
            if (i > 0) {
              spans.add(TextSpan(
                text: keyword,
                style: TextStyle(
                  fontSize: 12,
                  color: highlightColor,
                  fontWeight: FontWeight.bold,
                ),
              ));
            }
            if (parts[i].isNotEmpty) {
              spans.add(TextSpan(
                text: parts[i],
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[800],
                ),
              ));
            }
          }
          return TextSpan(children: spans);
        }
      }

      return TextSpan(
        text: text,
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey[800],
        ),
      );
    }

    return RichText(text: buildTextSpan());
  }

  // ==================== ACTION BUTTONS ====================
  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              side: BorderSide(color: Colors.grey[300]!),
            ),
            child: const Text(
              'Đóng',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ==================== HELPER FUNCTIONS ====================
  double? _safeParseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  String _getConfidenceText(double confidence) {
    if (confidence >= 0.8) return 'Rất phù hợp';
    if (confidence >= 0.6) return 'Khá phù hợp';
    if (confidence >= 0.4) return 'Có thể phù hợp';
    return 'Tham khảo thêm';
  }

  List<Color> _getConfidenceGradient(double confidence) {
    if (confidence >= 0.8) return [Colors.green[600]!, Colors.green[400]!];
    if (confidence >= 0.6) return [Colors.blue[600]!, Colors.blue[400]!];
    if (confidence >= 0.4) return [Colors.amber[600]!, Colors.amber[400]!];
    return [Colors.orange[600]!, Colors.orange[400]!];
  }
}

// ==================== SHOW EXPLANATION DIALOG ====================
void showAIExplanationDialog({
  required BuildContext context,
  required String userId,
  required String rentalId,
  required String rentalTitle,
}) {
  showDialog(
    context: context,
    builder: (context) => AIExplanationDialog(
      userId: userId,
      rentalId: rentalId,
      rentalTitle: rentalTitle,
    ),
  );
}
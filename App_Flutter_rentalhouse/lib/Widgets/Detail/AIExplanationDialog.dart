import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/vm_rental.dart';


/// 🔥 Widget hiển thị giải thích AI recommendation
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
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
              maxWidth: MediaQuery.of(context).size.width * 0.9,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ==================== HEADER ====================
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue[600]!, Colors.blue[400]!],
                      ),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(
                            Icons.psychology,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Giải Thích AI',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Tại sao bài này phù hợp với bạn?',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.85),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close, color: Colors.white, size: 20),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),

                  // ==================== CONTENT ====================
                  if (viewModel.isLoadingExplanation)
                    _buildLoadingState()
                  else if (viewModel.explanationError != null)
                    _buildErrorState(viewModel.explanationError!)
                  else if (viewModel.currentExplanation != null)
                      _buildExplanationContent(viewModel.currentExplanation!)
                    else
                      _buildEmptyState(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ==================== LOADING STATE ====================
  Widget _buildLoadingState() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[600]!),
            ),
          ),
          const SizedBox(height: 12),
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
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.red[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.error_outline,
              color: Colors.red[600],
              size: 28,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Không thể tải giải thích',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.red[600],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            error,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ==================== EMPTY STATE ====================
  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.info_outline,
            size: 28,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 10),
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
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ==================== CONFIDENCE SCORE ====================
          _buildConfidenceCard(explanation),
          const SizedBox(height: 16),

          // ==================== REASONS (MAIN CONTENT) ====================
          _buildReasons(explanation),
          const SizedBox(height: 16),

          // ==================== ACTION BUTTONS ====================
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Đóng',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[600],
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Xem Chi Tiết',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== CONFIDENCE CARD ====================
  Widget _buildConfidenceCard(AIExplanation explanation) {
    final confidence = _safeParseDouble(explanation.scores['confidence']) ?? 0.0;
    final confidencePercent = (confidence * 100).toStringAsFixed(0);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[50]!, Colors.blue[100]!],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Row(
        children: [
          // CONFIDENCE CIRCLE
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Colors.blue[600]!, Colors.blue[400]!],
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
          const SizedBox(width: 12),

          // TEXT
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Độ Tin Cậy',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _getConfidenceText(confidence),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                  ),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: confidence,
                    minHeight: 4,
                    backgroundColor: Colors.blue[200],
                    valueColor:
                    AlwaysStoppedAnimation<Color>(Colors.blue[600]!),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== REASONS (MAIN CONTENT) ====================
  Widget _buildReasons(AIExplanation explanation) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Lý Do Gợi Ý',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 10),

        // 🔥 HIỂN THỊ CÁC LÝ DO
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
    // 🔥 ICON TÙY THEO LOẠI LÝ DO
    IconData iconData = Icons.check_circle_outline;
    Color iconColor = Colors.green[600]!;

    if (title.toLowerCase().contains('location') ||
        title.toLowerCase().contains('vị trí')) {
      iconData = Icons.location_on;
      iconColor = Colors.orange[600]!;
    } else if (title.toLowerCase().contains('price') ||
        title.toLowerCase().contains('giá')) {
      iconData = Icons.local_offer;
      iconColor = Colors.purple[600]!;
    } else if (title.toLowerCase().contains('collaborative') ||
        title.toLowerCase().contains('user')) {
      iconData = Icons.people;
      iconColor = Colors.blue[600]!;
    }

    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              iconData,
              color: iconColor,
              size: 16,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatReasonLabel(title),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[700],
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
    if (confidence >= 0.8) return 'Rất phù hợp 🎯';
    if (confidence >= 0.6) return 'Khá phù hợp ✓';
    if (confidence >= 0.4) return 'Có thể phù hợp 👍';
    return 'Tham khảo thêm 🔍';
  }

  String _formatReasonLabel(String key) {
    const labels = {
      'collaborative': 'Người dùng tương tự',
      'collaborative_filtering': 'Người dùng tương tự',
      'location': 'Vị trí phù hợp',
      'price': 'Giá phù hợp',
      'preference': 'Sở thích của bạn',
      'amenities': 'Tiện ích',
      'interaction_count': 'Mức độ quan tâm',
    };

    if (labels.containsKey(key)) {
      return labels[key]!;
    }

    return key
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
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
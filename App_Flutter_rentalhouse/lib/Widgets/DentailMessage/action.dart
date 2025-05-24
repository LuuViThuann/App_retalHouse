import 'package:flutter/material.dart';

class ActionsCard extends StatelessWidget {
  final ThemeData appTheme;
  final bool isDeleting;
  final VoidCallback onDelete;

  const ActionsCard({
    super.key,
    required this.appTheme,
    required this.isDeleting,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final Color errorColor = appTheme.colorScheme.error;

    return Card(
      elevation: 4,
      shadowColor: errorColor.withOpacity(0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: isDeleting
            ? null
            : () {
                showDialog(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15)),
                    title: const Text('Xác nhận xóa'),
                    content: const Text(
                        'Bạn có chắc muốn xóa vĩnh viễn cuộc trò chuyện này? Hành động này không thể hoàn tác.'),
                    actionsAlignment: MainAxisAlignment.spaceEvenly,
                    actionsPadding:
                        const EdgeInsets.only(bottom: 10, left: 10, right: 10),
                    actions: [
                      TextButton(
                        style: TextButton.styleFrom(
                            foregroundColor: appTheme.textTheme.bodyLarge?.color
                                ?.withOpacity(0.8)),
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('Hủy'),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: errorColor,
                        ),
                        onPressed: () {
                          Navigator.pop(dialogContext);
                          onDelete();
                        },
                        child: const Text('Xóa',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                );
              },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: errorColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.delete_forever_rounded,
                    color: errorColor, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Xóa cuộc trò chuyện',
                  style: TextStyle(
                    color: errorColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (isDeleting)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: errorColor,
                  ),
                )
              else
                Icon(Icons.arrow_forward_ios,
                    size: 16, color: errorColor.withOpacity(0.7)),
            ],
          ),
        ),
      ),
    );
  }
}
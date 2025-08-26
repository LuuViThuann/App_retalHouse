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

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: isDeleting
          ? null
          : () {
              showDialog(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  title: Text(
                    'Xác nhận xóa',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.blue.shade800,
                    ),
                  ),
                  content: Text(
                    'Bạn có chắc muốn xóa vĩnh viễn cuộc trò chuyện này? Hành động này không thể hoàn tác.',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  actionsAlignment: MainAxisAlignment.spaceEvenly,
                  actionsPadding:
                      const EdgeInsets.only(bottom: 16, left: 16, right: 16),
                  actions: [
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey.shade600,
                      ),
                      onPressed: () => Navigator.pop(dialogContext),
                      child: Text(
                        'Hủy',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: errorColor,
                      ),
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        onDelete();
                      },
                      child: Text(
                        'Xóa',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: errorColor,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white, Colors.blue.shade50],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.shade100.withOpacity(0.2),
              blurRadius: 8,
              spreadRadius: 1,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(color: Colors.blue.shade100.withOpacity(0.5)),
        ),
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
                child: AnimatedScale(
                  scale: isDeleting ? 1.1 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(Icons.delete_forever_rounded,
                      color: errorColor, size: 28),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Xóa cuộc trò chuyện',
                  style: TextStyle(
                    color: errorColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
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
                AnimatedScale(
                  scale: 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: errorColor.withOpacity(0.7),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

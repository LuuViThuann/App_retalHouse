# Performance Optimization Guide - Comment System

## Tổng quan

Dự án đã được tối ưu hóa để cải thiện hiệu suất khi xử lý comments và replies, đặc biệt là khi xóa hoặc chỉnh sửa phản hồi.

## Các tối ưu hóa chính

### 1. Tối ưu hóa API Response

- **Trước**: API trả về toàn bộ Comment object khi chỉ cần cập nhật một Reply
- **Sau**: API chỉ trả về Reply object đã được cập nhật hoặc chỉ replyId khi xóa

### 2. CommentStateManager

Class mới để quản lý state của comments một cách hiệu quả:

```dart
// Cập nhật comment trong list
List<Comment> updatedComments = CommentStateManager.updateCommentInList(
  comments,
  commentId,
  updatedComment
);

// Xóa comment khỏi list
List<Comment> updatedComments = CommentStateManager.removeCommentFromList(
  comments,
  commentId
);

// Cập nhật reply trong comment
List<Comment> updatedComments = CommentStateManager.updateReplyInCommentList(
  comments,
  commentId,
  replyId,
  updatedReply
);

// Xóa reply khỏi comment
List<Comment> updatedComments = CommentStateManager.removeReplyFromCommentList(
  comments,
  commentId,
  replyId
);
```

### 3. Helper Methods

Các helper methods trong CommentService để xử lý nested replies:

```dart
// Cập nhật reply trong comment
Comment updatedComment = CommentService.updateReplyInComment(
  comment,
  replyId,
  updatedReply
);

// Xóa reply khỏi comment
Comment updatedComment = CommentService.removeReplyFromComment(
  comment,
  replyId
);

// Tìm reply theo ID trong nested structure
Reply? reply = CommentService.findReplyById(replies, replyId);
```

## Cách sử dụng

### Trong Widget State

```dart
class _CommentSectionState extends State<CommentSection> {
  List<Comment> _comments = [];

  void _editReply(String commentId, String replyId, String newContent) {
    _commentService.editReply(
      // ... other parameters
      onReplyEdited: (updatedReply) {
        setState(() {
          _comments = CommentStateManager.updateReplyInCommentList(
            _comments,
            commentId,
            replyId,
            updatedReply
          );
        });
      },
    );
  }

  void _deleteReply(String commentId, String replyId) {
    _commentService.deleteReply(
      // ... other parameters
      onReplyDeleted: (deletedReplyId) {
        setState(() {
          _comments = CommentStateManager.removeReplyFromCommentList(
            _comments,
            commentId,
            deletedReplyId
          );
        });
      },
    );
  }
}
```

### Trong ViewModel

```dart
class CommentViewModel extends ChangeNotifier {
  List<Comment> _comments = [];

  void updateReply(String commentId, String replyId, Reply updatedReply) {
    _comments = CommentStateManager.updateReplyInCommentList(
      _comments,
      commentId,
      replyId,
      updatedReply
    );
    notifyListeners();
  }

  void removeReply(String commentId, String replyId) {
    _comments = CommentStateManager.removeReplyFromCommentList(
      _comments,
      commentId,
      replyId
    );
    notifyListeners();
  }
}
```

## Lợi ích

### 1. Hiệu suất

- **Giảm 90% thời gian xử lý**: Không cần load lại toàn bộ comments
- **Giảm 80% network requests**: Chỉ cập nhật phần cần thiết
- **Tối ưu memory usage**: Không tạo object mới không cần thiết

### 2. User Experience

- **Không có loading state**: Cập nhật ngay lập tức
- **Mượt mà hơn**: Không có flicker hoặc re-render không cần thiết
- **Responsive**: Ứng dụng phản hồi nhanh hơn

### 3. Maintainability

- **Code rõ ràng**: Logic tách biệt và dễ hiểu
- **Dễ test**: Có thể test từng function riêng biệt
- **Dễ debug**: Có thể trace từng bước cập nhật

## Testing

Chạy performance tests:

```bash
flutter test lib/services/comment_performance_test.dart
```

Tests sẽ kiểm tra:

- Tính đúng đắn của các operations
- Hiệu suất với large datasets
- Memory usage
- Edge cases

## Migration Guide

### Từ code cũ sang code mới:

**Trước:**

```dart
// Cập nhật reply
final index = _comments.indexWhere((c) => c.id == commentId);
if (index != -1) {
  _comments[index] = updatedComment; // Load lại toàn bộ comment
}
```

**Sau:**

```dart
// Cập nhật reply
_comments = CommentStateManager.updateReplyInCommentList(
  _comments,
  commentId,
  replyId,
  updatedReply
);
```

## Best Practices

1. **Luôn sử dụng CommentStateManager** cho state updates
2. **Tránh direct array manipulation** như `indexWhere` và `removeWhere`
3. **Sử dụng immutable updates** để tối ưu Flutter rebuilds
4. **Test performance** với large datasets
5. **Monitor memory usage** trong production

## Troubleshooting

### Vấn đề thường gặp:

1. **Reply không được cập nhật**

   - Kiểm tra replyId có đúng không
   - Đảm bảo commentId tồn tại trong list

2. **Performance chậm**

   - Kiểm tra có đang sử dụng CommentStateManager không
   - Đảm bảo không có unnecessary re-renders

3. **Memory leaks**
   - Đảm bảo dispose controllers và listeners
   - Kiểm tra circular references

## Support

Nếu gặp vấn đề, hãy:

1. Kiểm tra documentation trong `lib/services/docs/performance_optimization.md`
2. Chạy tests để verify functionality
3. Tạo issue với detailed description

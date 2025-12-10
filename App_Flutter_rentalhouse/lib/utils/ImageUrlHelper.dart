import '../config/api_routes.dart';

///  HELPER CLASS: Xử lý URL ảnh từ Cloudinary hoặc server cũ
class ImageUrlHelper {
  /// Chuyển đổi URL ảnh về dạng đầy đủ
  /// - Nếu URL đã là Cloudinary (https://res.cloudinary.com/...) → dùng trực tiếp
  /// - Nếu là đường dẫn tương đối (/uploads/...) → ghép với serverBaseUrl
  static String getImageUrl(String imageUrl) {
    if (imageUrl.isEmpty) return '';

    // Nếu URL đã là đường dẫn đầy đủ (http:// hoặc https://)
    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      return imageUrl;
    }

    // Nếu là đường dẫn tương đối (ảnh cũ từ server)
    // Đảm bảo không bị duplicate slash
    if (imageUrl.startsWith('/')) {
      return '${ApiRoutes.serverBaseUrl}$imageUrl';
    }

    return '${ApiRoutes.serverBaseUrl}/$imageUrl';
  }

  /// Xử lý danh sách URL ảnh
  static List<String> getImageUrls(List<String> imageUrls) {
    return imageUrls.map((url) => getImageUrl(url)).toList();
  }

  /// Kiểm tra URL có phải từ Cloudinary không
  static bool isCloudinaryUrl(String url) {
    return url.contains('cloudinary.com') || url.contains('res.cloudinary');
  }

  /// Kiểm tra URL có phải video không (dựa vào extension)
  static bool isVideoUrl(String url) {
    final videoExtensions = ['.mp4', '.mov', '.avi', '.mkv', '.webm'];
    final lowerUrl = url.toLowerCase();
    return videoExtensions.any((ext) => lowerUrl.endsWith(ext));
  }

  /// Lấy URL thumbnail cho video (nếu có)
  /// Cloudinary tự động generate thumbnail cho video
  static String getVideoThumbnail(String videoUrl) {
    if (!isCloudinaryUrl(videoUrl)) return videoUrl;

    // Cloudinary video thumbnail: thay .mp4 → .jpg và thêm transformation
    // VD: https://res.cloudinary.com/.../video.mp4
    //  → https://res.cloudinary.com/.../video.jpg
    return videoUrl
        .replaceAll('.mp4', '.jpg')
        .replaceAll('.mov', '.jpg')
        .replaceAll('.avi', '.jpg')
        .replaceAll('.mkv', '.jpg')
        .replaceAll('.webm', '.jpg');
  }
}
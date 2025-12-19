// services/vnpay_handler.dart
/// Deprecated VNPay client-side handler.
///
/// To đảm bảo đồng bộ tuyệt đối với backend (NodeJS `vnpayService`)
/// và tránh lỗi sai chữ ký, toàn bộ việc:
/// - sinh `vnp_TxnRef`, `vnp_Amount`, `vnp_CreateDate`, …
/// - ký HMAC SHA512 (`vnp_SecureHash`)
/// - xác minh chữ ký khi RETURN / IPN
///
/// đều đã được chuyển HOÀN TOÀN sang backend.
///
/// Flutter chỉ cần:
/// - Gọi API `POST /api/vnpay/create-payment` để lấy `paymentUrl`
/// - Mở `paymentUrl` trong WebView / browser
/// - Sau khi người dùng thanh toán, gọi
///   `GET /api/vnpay/check-payment/:transactionCode` để kiểm tra trạng thái
///
/// File này được giữ lại như một stub trống để tránh lỗi import.
class VNPayHandler {}

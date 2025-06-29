# Hướng dẫn thiết lập tính năng "Book Now" cho ứng dụng Flutter Rental House

## Tổng quan

Tính năng "Book Now" cho phép người dùng đặt chỗ xem nhà từ các bài đăng cho thuê. Hệ thống bao gồm:

- Frontend Flutter với giao diện đặt chỗ
- Backend Node.js với MongoDB
- Quản lý trạng thái booking
- Thông báo cho chủ nhà và khách hàng

## Tính năng đã triển khai

### 1. Ngăn chặn tự đặt chỗ cho bài viết của chính mình

- ✅ Kiểm tra người dùng hiện tại với userId của bài viết
- ✅ Ẩn nút "Đặt chỗ ngay" trong rental_detail_view
- ✅ Hiển thị thông báo "Đây là bài viết của bạn" thay thế
- ✅ Chặn truy cập booking_view với thông báo lỗi

### 2. Định dạng tiền tệ VNĐ đúng cách

- ✅ Sử dụng NumberFormat.currency với locale 'vi_VN'
- ✅ Hiển thị đúng định dạng: "1,000,000 VNĐ/tháng"
- ✅ Áp dụng cho tất cả màn hình liên quan đến giá

### 3. Hiển thị thông tin chủ bài viết

- ✅ Hiển thị tên chủ nhà từ contactInfo
- ✅ Hiển thị số điện thoại liên hệ
- ✅ Hiển thị giờ liên hệ (availableHours)
- ✅ Giao diện đẹp với avatar và thông tin chi tiết

### 4. Trang "Hợp đồng của tôi" trong Profile

- ✅ Tạo MyBookingsView hiển thị danh sách booking
- ✅ Hiển thị thông tin: ID booking, tên khách, SĐT, thời gian xem
- ✅ Trạng thái booking với màu sắc phân biệt
- ✅ Pull-to-refresh để cập nhật dữ liệu
- ✅ Điều hướng đến chi tiết booking

### 5. Trang chi tiết Booking

- ✅ Tạo BookingDetailView hiển thị thông tin đầy đủ
- ✅ Thông tin đặt chỗ: thời gian, ngày tạo, cập nhật
- ✅ Thông tin khách hàng: tên, SĐT, email, ghi chú
- ✅ Ghi chú từ chủ nhà (nếu có)
- ✅ Nút hủy đặt chỗ (chỉ khi status = 'pending')

## Cấu trúc file đã tạo/cập nhật

### Frontend (Flutter)

```
lib/
├── models/
│   └── booking.dart                    # Model Booking
├── services/
│   └── booking_service.dart            # API service cho booking
├── viewmodels/
│   └── vm_booking.dart                 # State management cho booking
├── views/
│   ├── booking_view.dart               # Form đặt chỗ (đã cập nhật)
│   ├── my_bookings_view.dart           # Danh sách booking của user
│   ├── booking_detail_view.dart        # Chi tiết booking
│   ├── rental_detail_view.dart         # Đã cập nhật - ẩn nút đặt chỗ
│   └── profile_view.dart               # Đã cập nhật - điều hướng
└── main.dart                           # Đã cập nhật - thêm BookingViewModel
```

### Backend (Node.js)

```
backend/
├── models/
│   ├── booking.js                      # Schema Booking
│   └── notification.js                 # Schema Notification
└── routes/
    └── bookings.js                     # API routes cho booking
```

## API Endpoints

### Booking Management

- `POST /api/bookings` - Tạo booking mới
- `GET /api/bookings/my` - Lấy booking của user hiện tại
- `GET /api/bookings/rental/:rentalId` - Lấy booking của một bài viết
- `PUT /api/bookings/:id/status` - Cập nhật trạng thái booking
- `DELETE /api/bookings/:id` - Hủy booking
- `GET /api/bookings/:id` - Lấy chi tiết booking

## Cách sử dụng

### 1. Đặt chỗ xem nhà

1. Người dùng xem chi tiết bài viết cho thuê
2. Nhấn nút "Đặt chỗ ngay" (chỉ hiển thị nếu không phải bài viết của mình)
3. Điền thông tin liên hệ và chọn thời gian xem
4. Nhấn "Đặt chỗ ngay" để gửi yêu cầu

### 2. Xem hợp đồng của mình

1. Vào Profile → "Hợp đồng của tôi"
2. Xem danh sách các booking đã đặt
3. Nhấn vào booking để xem chi tiết
4. Có thể hủy booking nếu đang ở trạng thái "Chờ xác nhận"

### 3. Quản lý booking (cho chủ nhà)

1. Vào bài viết của mình
2. Xem danh sách booking
3. Cập nhật trạng thái: xác nhận, từ chối, hoàn thành
4. Thêm ghi chú cho khách hàng

## Trạng thái Booking

- `pending` - Chờ xác nhận (màu cam)
- `confirmed` - Đã xác nhận (màu xanh dương)
- `completed` - Hoàn thành (màu xanh lá)
- `cancelled` - Đã hủy (màu đỏ)

## Tính năng bảo mật

- ✅ Xác thực JWT cho tất cả API
- ✅ Kiểm tra quyền sở hữu booking
- ✅ Ngăn chặn tự đặt chỗ cho bài viết của mình
- ✅ Validation dữ liệu đầu vào

## Troubleshooting

### Lỗi thường gặp

1. **ProviderNotFoundException**: Đảm bảo BookingViewModel đã được thêm vào MultiProvider trong main.dart
2. **API Error**: Kiểm tra backend server và database connection
3. **Validation Error**: Kiểm tra format dữ liệu đầu vào

### Debug

- Kiểm tra console log để xem lỗi API
- Sử dụng Flutter Inspector để debug UI
- Kiểm tra Network tab trong DevTools

## Cập nhật gần đây

- ✅ Thêm kiểm tra ngăn chặn tự đặt chỗ
- ✅ Cải thiện định dạng tiền tệ VNĐ
- ✅ Thêm hiển thị thông tin chủ nhà
- ✅ Tạo trang "Hợp đồng của tôi" hoàn chỉnh
- ✅ Thêm trang chi tiết booking
- ✅ Cải thiện UX với thông báo và loading states
- ✅ **MỚI**: Hiển thị thông tin bài viết trong booking detail
- ✅ **MỚI**: Điều hướng đến chi tiết bài viết từ booking
- ✅ **MỚI**: Hiển thị thông tin chủ tài khoản bài viết
- ✅ **MỚI**: Nút xóa hợp đồng khi đã hủy
- ✅ **MỚI**: Cập nhật model Booking với thông tin bài viết và chủ nhà
- ✅ **MỚI**: Thêm API delete booking cho hợp đồng đã hủy

## Tính năng mới trong Booking Detail View

### 1. Hiển thị thông tin bài viết

- Hiển thị tiêu đề, địa chỉ, giá của bài viết đã đặt
- Hình ảnh thumbnail của bài viết
- Nút điều hướng đến chi tiết bài viết

### 2. Thông tin chủ tài khoản bài viết

- Tên chủ nhà với avatar
- Số điện thoại liên hệ
- Email (nếu có)

### 3. Nút xóa hợp đồng

- Chỉ hiển thị khi booking có trạng thái 'cancelled'
- Xác nhận trước khi xóa
- Xóa vĩnh viễn khỏi danh sách

### 4. Cập nhật Model và API

- Model Booking: thêm trường rentalTitle, rentalAddress, rentalPrice, rentalImage, ownerName, ownerPhone, ownerEmail
- BookingService: thêm method deleteBooking
- BookingViewModel: thêm method deleteBooking

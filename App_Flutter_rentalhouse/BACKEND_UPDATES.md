# Cập nhật Backend - Hoàn thiện Booking API

## Các thay đổi đã thực hiện

### 1. Sửa lỗi và cải thiện

#### Sửa lỗi duplicate route

- **Vấn đề:** Có 2 route GET `/bookings/:bookingId` bị trùng lặp
- **Giải pháp:** Xóa route trùng lặp và giữ lại route hoàn chỉnh nhất

#### Cập nhật populate fields

- **Trước:** Chỉ populate các field cơ bản
- **Sau:** Populate đầy đủ tất cả fields cần thiết:
  ```javascript
  .populate('rentalId', 'title price location images status contactInfo userId propertyType area amenities furniture surroundings rentalTerms')
  ```

### 2. Cải thiện API Responses

#### Route GET `/bookings/my-bookings`

**Thêm thông tin rental vào response:**

```javascript
// Add rental information to the response
if (booking.rentalId) {
  adjusted.rentalTitle = booking.rentalId.title;
  adjusted.rentalAddress = booking.rentalId.location?.fullAddress;
  adjusted.rentalPrice = booking.rentalId.price;
  adjusted.rentalImage = booking.rentalId.images?.[0];
  adjusted.ownerName = booking.rentalId.contactInfo?.name;
  adjusted.ownerPhone = booking.rentalId.contactInfo?.phone;
  adjusted.ownerEmail = booking.rentalId.contactInfo?.email;
  adjusted.propertyType = booking.rentalId.propertyType;
  adjusted.area = booking.rentalId.area;
  adjusted.amenities = booking.rentalId.amenities;
  adjusted.furniture = booking.rentalId.furniture;
  adjusted.surroundings = booking.rentalId.surroundings;
  adjusted.rentalTerms = booking.rentalId.rentalTerms;
}
```

#### Route GET `/bookings/:bookingId`

**Trả về đầy đủ thông tin rental:**

```javascript
const responseData = {
  ...booking,
  rentalTitle: booking.rentalId?.title,
  rentalAddress: booking.rentalId?.location?.fullAddress,
  rentalPrice: booking.rentalId?.price,
  rentalImage: booking.rentalId?.images?.[0],
  ownerName: booking.rentalId?.contactInfo?.name,
  ownerPhone: booking.rentalId?.contactInfo?.phone,
  ownerEmail: booking.rentalId?.contactInfo?.email,
  propertyType: booking.rentalId?.propertyType,
  area: booking.rentalId?.area,
  amenities: booking.rentalId?.amenities,
  furniture: booking.rentalId?.furniture,
  surroundings: booking.rentalId?.surroundings,
  rentalTerms: booking.rentalId?.rentalTerms,
  // ... timestamps
};
```

### 3. Cấu trúc API hoàn chỉnh

#### Các routes hiện có:

1. **POST `/bookings`** - Tạo booking mới
2. **GET `/bookings/my-bookings`** - Lấy danh sách booking của user
3. **GET `/bookings/rental/:rentalId`** - Lấy danh sách booking cho chủ nhà
4. **PATCH `/bookings/:bookingId/status`** - Cập nhật trạng thái booking
5. **PATCH `/bookings/:bookingId/cancel`** - Hủy booking
6. **GET `/bookings/:bookingId`** - Lấy chi tiết booking
7. **DELETE `/bookings/:bookingId`** - Xóa booking đã hủy

### 4. Thông tin trả về đầy đủ

#### Booking Detail Response:

```json
{
  "_id": "booking_id",
  "userId": "user_id",
  "rentalId": "rental_id",
  "customerInfo": {
    "name": "Tên khách hàng",
    "phone": "Số điện thoại",
    "email": "Email",
    "message": "Ghi chú"
  },
  "bookingDate": "2024-01-01T00:00:00.000Z",
  "preferredViewingTime": "Thời gian xem",
  "status": "pending",
  "ownerNotes": "Ghi chú từ chủ nhà",
  "createdAt": "2024-01-01T00:00:00.000Z",
  "updatedAt": "2024-01-01T00:00:00.000Z",

  // Thông tin bài viết
  "rentalTitle": "Tiêu đề bài viết",
  "rentalAddress": "Địa chỉ đầy đủ",
  "rentalPrice": 5000000,
  "rentalImage": "URL hình ảnh",
  "propertyType": "Loại bất động sản",
  "area": {
    "total": 100,
    "livingRoom": 30,
    "bedrooms": 50,
    "bathrooms": 20
  },
  "amenities": ["Tiện ích 1", "Tiện ích 2"],
  "furniture": ["Nội thất 1", "Nội thất 2"],
  "surroundings": ["Xung quanh 1", "Xung quanh 2"],
  "rentalTerms": {
    "minimumLease": "12 tháng",
    "deposit": "2 tháng tiền cọc",
    "paymentMethod": "Chuyển khoản",
    "renewalTerms": "Gia hạn 12 tháng"
  },

  // Thông tin chủ nhà
  "ownerName": "Tên chủ nhà",
  "ownerPhone": "Số điện thoại chủ nhà",
  "ownerEmail": "Email chủ nhà"
}
```

### 5. Bảo mật và Validation

#### Authentication:

- Sử dụng Firebase Admin SDK để verify token
- Middleware kiểm tra token cho tất cả routes

#### Authorization:

- Kiểm tra quyền sở hữu booking khi cần thiết
- Kiểm tra quyền sở hữu rental cho chủ nhà

#### Validation:

- Validate ObjectId trước khi query database
- Kiểm tra trạng thái booking hợp lệ
- Validate required fields

### 6. Error Handling

#### Các loại lỗi được xử lý:

- **400:** Invalid input data
- **401:** Unauthorized (no token/invalid token)
- **403:** Forbidden (no permission)
- **404:** Resource not found
- **500:** Internal server error

#### Error Response Format:

```json
{
  "message": "Error description",
  "error": "Detailed error message (optional)"
}
```

### 7. Timezone Handling

#### Timestamp Adjustment:

- Tất cả timestamps được điều chỉnh +7 giờ (Vietnam timezone)
- Áp dụng cho createdAt, updatedAt, bookingDate

### 8. Notification System

#### Tự động tạo notification cho:

- Tạo booking mới
- Cập nhật trạng thái booking
- Hủy booking
- Xóa booking

#### Notification Content:

- Thông báo cho chủ nhà khi có booking mới
- Thông báo cho khách hàng khi trạng thái thay đổi
- Thông báo cho chủ nhà khi booking bị hủy/xóa

## Lợi ích của cập nhật

1. **Dữ liệu đầy đủ:** Frontend nhận được tất cả thông tin cần thiết
2. **Hiệu suất tốt:** Populate đầy đủ trong một query
3. **Bảo mật cao:** Kiểm tra quyền truy cập chặt chẽ
4. **Error handling:** Xử lý lỗi toàn diện
5. **Timezone consistency:** Đồng bộ múi giờ Việt Nam
6. **Notification system:** Thông báo tự động cho người dùng

Thông tin mô tả công nghệ sử dụng và chức năng trong ứng dụng bất động sản : nền tảng cho người dùng và môi giới
*-------------------------------------------------------------------------
* CÔNG NGHỆ SỬ DỤNG : 
--------------------
- Về phía Front-End
+ Dart / Flutter 
-------------------
- Về phía Backend : 
+ NodeJS / ExpressJS : xử lý các logic API 
+ Python : Xử lý thông tin bài đăng và gợi ý cá nhân hóa người dùng
+ Flutter xử lý đồng bộ dữ liệu 2 bên 
-------------------
- Database : 
+ MongoDB - NoSQL : Tận dụng Geospatial tích hợp xử lý logic hiển thị các bài gợi ý xung quanh
+ Firebase : Lưu trữ thông tin người dùng + tích hợp login Google
-------------------
- Các công nghệ và dịch vụ khác liên quan : 
+ Tích hợp VNPay thanh toán khi đăng bài trong môi trường sanbox-test
+ Cloudinary : Lưu trữ các hình ảnh và tối ưu dung lượng ảnh , sau đó lưu link ảnh URL trong DB 
+ Redis : Cache dữ liệu tạm thời gọi lại nhanh hơn , không tốn query truy vấn lại trong DB 
+ Docker : Tạo môi trường chạy đồng nhất cho Node-JS , Redis , mongoDB , Elasticsearch , NodeJS 
+ Socket.IO : Chạy dữ liệu thời gian thực 
+ ElasticSearch : tối ưu chỉ mục cho tìm kiếm các bài viết
+ PostMan : Kiểm thử các API 
+ Sử dụng Nominatim - OpenStreetMap dịch vụ bản đồ để chuyển địa chỉ sang tọa độ
+ Tích hợp KEY từ OpenAI : cho chức năng chat giao tiếp tư vấn 
+ Sử dụng Bcrypt chuyển mật khẩu sang chuỗi hash lưu trong DB.
*-------------------------------------------------------------------------
* THÔNG TIN CHỨC NĂNG CÓ TRONG ỨNG DỤNG : 
- Các chức năng hiện tại đang xây dựng : 
+ Đăng nhập / Đăng ký / Khôi phục pass qua Email / Đăng nhập GG
+ Hiển thị các thông tin loại bất động sản / bài mới tại trang chính 
+ Tìm kiếm thông tin BĐS theo loại / từ khóa / khoảng giá 
+ Đăng bài tính phí thanh toán thông qua test VNPay
+ Tìm kiếm các BĐS thông qua tương tác trên bản đồ và hiển thị các gợi ý các bài đăng khác trong bán kính vị trí đó 
+ Lọc khoảng giá trong bán kính đang xem trên bản đồ
+ Lưu lịch sử giao dịch thanh toán
+ Tạo cuộc trò chuyện và nhắn tin thông qua bài viết của người đăng BĐS 
+ ChatBox - AI tư vấn BĐS 
+ Lưu yêu thích các BĐS 
+ Xem chi tiết thông tin BĐS và bình luận / phản hồi / đánh giá cho người dùng trong chi tiết bài đăng
+ Lưu các thông báo tương tác gần đây trong app
+ Đăng gửi các góp ý & phản hồi 
+ Thông tin hồ sơ cá nhân 
+ Xem danh sách bài đăng thuộc trong tài khoản
+ Danh sách tin tức 
*-------------------------------------------------------------------------
* TỔNG QUAN VỀ THÔNG TIN THỐNG KÊ TRONG ỨNG DỤNG : 
---
1. Thống kê theo khu vực (biểu đồ cột, phân bố theo tỉnh/quận/phường)
2. Thống kê tiện nghi & nội thất (biểu đồ tròn, phân bố các tiện nghi phổ biến)
3. Thống kê tăng trưởng theo thời gian
4. Hành vi người dùng (lượt xem, yêu thích, liên hệ, tỷ lệ chuyển đổi)
5. Phân bố diện tích (biểu đồ cột hoặc box plot)
6. Phân bố giá (biểu đồ cột hoặc box plot)
7. Phân loại BĐS (biểu đồ tròn, % nhà nguyên căn, chung cư, văn phòng, v.v.)
8. Khu vực nổi bật (danh sách top 5-10 khu vực có nhiều BĐS nhất)
9. Tổng quan (các chỉ số chính: tổng số BĐS, giá TB, khu vực hot nhất)
*-------------------------------------------------------------------------
*TRAIN MODEL AI - Sử dụng Python cá nhân hóa gợi ý cho USER :

--------------

1. "Phù hợp sở thích" (content_score) — 0-100%

+ Giá các bài user đã xem/yêu thích : So sánh giá bài này với avg_price, min_price, max_price của user

+ Loại BĐS user hay xem (Nhà riêng, Phòng trọ...) : Tỉ lệ % loại BĐS này trong lịch sử

+ Vị trí các bài user đã xem : Khoảng cách từ bài này đến trung tâm vị trí user

--------------

2. "Người dùng tương tự" (cf_score) — 0-100% 

Đây là điểm Collaborative Filtering — tìm người dùng có hành vi giống user hiện tại

+ Toàn bộ lịch sử interactions : Ma trận user × rental với điểm tương tác

+ Cosine similarity giữa các user : User A và User B "giống nhau" đến mức nào

+ view=1, click=2, favorite=5, contact=8 : Mức độ quan tâm

Ví dụ thực tế:

User A (bạn) đã xem: bài 1, 2, 3, 4
User B (tương tự 85%): đã xem bài 1, 2, 3 và yêu thích bài 5
User C (tương tự 70%): đã xem bài 2, 4 và liên hệ bài 5
→ cf_score của bài 5 cao vì nhiều người giống bạn quan tâm nó

--------------

3.  "Độ phổ biến" (popularity_score) — 0-100% -> Dành cho gợi ý chẳng hạn như các tài khoản mới 

Đây là điểm Popularity-Based — không phụ thuộc vào user cụ thể

+ Tổng điểm tất cả interactions của bài : Bài được quan tâm nhiều cỡ nào

+ Số user khác nhau tương tác : Độ rộng của sự quan tâm
*-------------------------------------------------------------------------

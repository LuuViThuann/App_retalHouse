🏠 ỨNG DỤNG BẤT ĐỘNG SẢN - AI GỢI Ý CHUYÊN NGHIỆP – Mobile Application

Ứng dụng bất động sản trên nền tảng mobile được xây dựng nhằm kết nối người tìm bất động sản với môi giới hoặc người đăng tin.
Hệ thống hỗ trợ tìm kiếm, gợi ý bất động sản cá nhân hóa, tương tác theo thời gian thực và phân tích dữ liệu thị trường.

Ứng dụng được thiết kế theo mô hình Client–Server, tích hợp nhiều công nghệ hiện đại để đảm bảo hiệu năng, khả năng mở rộng và trải nghiệm người dùng tốt.

🚀 Technology Stack
1. Frontend

Dart / Flutter

Xây dựng ứng dụng mobile đa nền tảng.

Quản lý trạng thái và giao diện người dùng.

Đồng bộ dữ liệu với hệ thống backend thông qua REST API.

2. Backend

Node.js / Express.js

Xây dựng RESTful API.

Xử lý business logic của hệ thống.

Quản lý authentication, giao dịch và dữ liệu bài đăng.

Python

Xử lý dữ liệu bài đăng.

Xây dựng mô hình AI gợi ý bất động sản cá nhân hóa cho người dùng.

3. Database

MongoDB (NoSQL Database)

Lưu trữ dữ liệu bài đăng bất động sản.

Sử dụng Geospatial Index để hỗ trợ tìm kiếm bất động sản theo vị trí và bán kính.

Firebase

Lưu trữ thông tin người dùng.

Tích hợp Google Authentication.

4. Supporting Technologies & Services

VNPay (Sandbox)

Tích hợp thanh toán cho chức năng đăng tin bất động sản.

Cloudinary

Lưu trữ và tối ưu hình ảnh.

Lưu URL ảnh vào cơ sở dữ liệu.

Redis

Cache dữ liệu tạm thời.

Giảm tải truy vấn trực tiếp vào database.

Docker

Tạo môi trường chạy đồng nhất cho các service:

NodeJS

MongoDB

Redis

Elasticsearch

Socket.IO

Xử lý dữ liệu real-time cho hệ thống chat.

Elasticsearch

Tối ưu hóa tìm kiếm bài đăng bất động sản.

Postman

Kiểm thử và phát triển API.

Nominatim – OpenStreetMap

Chuyển đổi địa chỉ sang tọa độ địa lý (Geocoding).

OpenAI API

Tích hợp chatbot AI tư vấn bất động sản.

Bcrypt

Mã hóa mật khẩu trước khi lưu vào database.

📱 Application Features
🔐 Authentication

Đăng ký tài khoản

Đăng nhập

Khôi phục mật khẩu qua Email

Đăng nhập bằng Google

🏘️ Real Estate Listing

Hiển thị danh sách bất động sản mới nhất

Phân loại theo loại bất động sản

Xem chi tiết bài đăng

Bình luận và đánh giá bài đăng

🔍 Search & Filter

Tìm kiếm theo:

Từ khóa

Loại bất động sản

Khoảng giá

Lọc kết quả theo nhiều tiêu chí.

🗺️ Map-based Search

Hiển thị bất động sản trên bản đồ.

Tìm kiếm bất động sản trong bán kính vị trí trên bản đồ.

Lọc giá trong khu vực đang xem.

💰 Posting & Payment

Đăng bài bất động sản có phí.

Thanh toán qua VNPay Sandbox.

Lưu lịch sử giao dịch.

💬 Communication

Tạo cuộc trò chuyện giữa người dùng và người đăng tin.

Nhắn tin real-time thông qua Socket.IO.

❤️ User Interaction

Lưu bất động sản yêu thích.

Lưu lịch sử tương tác.

Nhận thông báo hoạt động gần đây.

🤖 AI Chatbot

Chatbot hỗ trợ tư vấn bất động sản.

Sử dụng OpenAI API để tạo hội thoại thông minh.

👤 User Profile

Quản lý hồ sơ cá nhân.

Xem danh sách bài đăng của tài khoản.

Gửi phản hồi và góp ý.

📰 News

Cập nhật tin tức liên quan đến thị trường bất động sản.

📊 Data Analytics & Statistics

Hệ thống cung cấp các chức năng thống kê dữ liệu nhằm hỗ trợ phân tích thị trường:

Thống kê theo khu vực

Biểu đồ cột

Phân bố theo tỉnh / quận / phường.

Thống kê tiện nghi & nội thất

Biểu đồ tròn

Phân bố các tiện nghi phổ biến.

Thống kê tăng trưởng theo thời gian

Phân tích hành vi người dùng

Lượt xem

Yêu thích

Liên hệ

Tỷ lệ chuyển đổi.

Phân bố diện tích bất động sản

Phân bố giá

Phân loại bất động sản

Nhà riêng

Chung cư

Văn phòng

Phòng trọ.

Khu vực nổi bật

Top 5–10 khu vực có nhiều bất động sản nhất.

Tổng quan hệ thống

Tổng số bất động sản

Giá trung bình

Khu vực hot nhất.

🤖 AI Recommendation System

Hệ thống sử dụng Python để xây dựng mô hình gợi ý bất động sản cá nhân hóa cho người dùng.

1️⃣ Content-Based Recommendation (content_score)

Đánh giá mức độ phù hợp với sở thích của người dùng (0–100%).

Các yếu tố:

Giá bất động sản

So sánh với:

avg_price

min_price

max_price

Loại bất động sản

Dựa trên tần suất loại bất động sản trong lịch sử tương tác.

Vị trí

Khoảng cách từ bất động sản đến khu vực người dùng quan tâm.

2️⃣ Collaborative Filtering (cf_score)

Xác định các người dùng có hành vi tương tự.

Phương pháp:

Xây dựng user × rental interaction matrix

Tính Cosine Similarity giữa các người dùng.

Trọng số tương tác:

| Action   | Score |
| -------- | ----- |
| View     | 1     |
| Click    | 2     |
| Favorite | 5     |
| Contact  | 8     |

3️⃣ Popularity-Based Recommendation (popularity_score)

Sử dụng cho các trường hợp như người dùng mới (cold start).

Các yếu tố:

Tổng điểm tương tác của bài đăng.

Số lượng người dùng khác nhau đã tương tác.

✔️ Ba điểm số được kết hợp để tạo ra danh sách gợi ý bất động sản tối ưu cho từng người dùng.

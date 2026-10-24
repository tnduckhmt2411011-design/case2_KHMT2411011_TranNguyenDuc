# Case Study 2: Ứng dụng Quản lý và Giao công việc nhóm (Task Manager)

- **MSSV:** KHMT2411011
- **Họ và tên:** Trần Nguyễn Đức
- **GitHub Repository:** [case2_KHMT2411011_TranNguyenDuc](https://github.com/tnduckhmt2411011-design/case2_KHMT2411011_TranNguyenDuc)

---

## 1. Giới thiệu tổng quan
Dự án **Task Manager** xây dựng theo kiến trúc Monorepo gồm 2 thành phần chính:
- **Backend (`api/`):** REST API xây dựng bằng Node.js, Express, MongoDB (Mongoose ODM), JWT, bcryptjs.
- **Frontend (`TaskManager/`):** Ứng dụng di động đa nền tảng bằng Flutter, giao diện Material 3 sạch sẽ, trực quan.

---

## 2. Cấu trúc Monorepo
```
case2_KHMT2411011_TranNguyenDuc/
├── api/                             # Backend RESTful API
│   ├── src/
│   │   ├── config/database.js       # Kết nối MongoDB Atlas
│   │   ├── controllers/             # authController.js, taskController.js
│   │   ├── middleware/              # authMiddleware.js, errorMiddleware.js
│   │   ├── models/                  # User.js, Task.js, TaskShare.js
│   │   ├── routes/                  # authRoutes.js, taskRoutes.js
│   │   ├── services/                # taskService.js (kiểm tra phân quyền)
│   │   ├── validators/              # authValidator.js
│   │   ├── app.js                   # Cấu hình Express app
│   │   └── server.js                # Khởi động server
│   ├── .env.example                 # Mẫu biến môi trường
│   ├── .gitignore                   # Loại trừ .env, node_modules
│   └── package.json
├── TaskManager/                     # Frontend Flutter Mobile Client
│   ├── android/app/src/debug/       # AndroidManifest.xml (usesCleartextTraffic)
│   ├── lib/
│   │   ├── models/                  # user.dart, task.dart
│   │   ├── screens/
│   │   │   ├── auth/                # auth_gate.dart, login_screen.dart, register_screen.dart
│   │   │   └── tasks/               # task_list_screen.dart, task_detail_screen.dart
│   │   ├── services/                # api_client.dart, auth_service.dart, task_service.dart
│   │   ├── utils/                   # constants.dart, validators.dart, date_formatter.dart
│   │   ├── widgets/                 # task_card.dart, status_badge.dart, priority_badge.dart, loading_view.dart
│   │   ├── app.dart
│   │   └── main.dart
│   ├── test/                        # auth_and_task_test.dart, widget_test.dart
│   └── pubspec.yaml
├── .gitignore                       # Root gitignore bảo vệ bảo mật
└── README.md
```

---

## 3. Cấu hình biến môi trường và cài đặt

### 3.1. Cấu hình Backend (`api/.env`)
Tạo file `api/.env` dựa theo mẫu `api/.env.example`:
```env
PORT=3000
MONGODB_URI=mongodb+srv://<username>:<password>@duc16.9mr2vnm.mongodb.net/task_manager?retryWrites=true&w=majority
JWT_SECRET=chuoi_hex_ngau_nhien_32_bytes
JWT_EXPIRES_IN=7d
```
> **Lưu ý bảo mật:** File `.env` chứa mật khẩu cơ sở dữ liệu và JWT secret tuyệt đối không commit lên Git (đã được cấu hình trong `.gitignore`).

### 3.2. Cài đặt và chạy Backend
```bash
cd api
npm install
# Chạy ở chế độ phát triển (tự động reload khi sửa file):
npm run dev
# Hoặc chạy thông thường:
npm start
```
Server sẽ chạy tại `http://localhost:3000`. Kiểm tra endpoint `GET /` trả về `{ "message": "Task Manager API dang hoat dong" }`.

### 3.3. Cài đặt và chạy Flutter Mobile App
```bash
cd TaskManager
flutter pub get
flutter run
```
- Trên **máy ảo Android Emulator**, base URL được định tuyến qua `http://10.0.2.2:3000/api` (cấu hình trong `lib/utils/constants.dart`).
- Để cho phép giao tiếp HTTP trong môi trường debug, cờ `android:usesCleartextTraffic="true"` đã được bật tại `TaskManager/android/app/src/debug/AndroidManifest.xml`.

---

## 4. Các chức năng và Endpoint đã hoàn thành (Buổi 1)

### 4.1. Nhóm A - Xác thực tài khoản
- `POST /api/auth/register`: Đăng ký tài khoản (validate fullName không rỗng, email hợp lệ, password >= 6 ký tự, băm bcryptjs, email trùng trả 409, không trả passwordHash).
- `POST /api/auth/login`: Đăng nhập bằng email và mật khẩu (sai email hoặc sai mật khẩu đều trả 401 cùng thông điệp `"Email hoặc mật khẩu không đúng"`, thành công trả JWT token và thông tin người dùng).
- `GET /api/auth/me`: Lấy thông tin tài khoản hiện tại từ JWT Bearer token (thiếu/sai/hết hạn trả 401).

### 4.2. Nhóm B - Đọc dữ liệu công việc (Read)
- `GET /api/tasks`: Lấy danh sách công việc người gọi có quyền truy cập (hỗ trợ tham số lọc `scope=created|assigned|shared`, mặc định lấy tất cả).
- `GET /api/tasks/:id`: Lấy chi tiết công việc. Xử lý chính xác:
  - ID không đúng định dạng ObjectId: `400 Bad Request`
  - Công việc không tồn tại: `404 Not Found`
  - Công việc tồn tại nhưng người dùng không có quyền truy cập: `403 Forbidden`
  - Trả về chi tiết: người tạo, người phụ trách, người được giao, người được chia sẻ và vai trò của người gọi (`creator`, `assignee`, `viewer`, `editor`). Tuyệt đối không trả `passwordHash`.

### 4.3. Giao diện Flutter
- `AuthGate`: Tự động kiểm tra token lưu trong `SharedPreferences`, điều hướng vào `TaskListScreen` nếu token hợp lệ, hoặc điều hướng về `LoginScreen` nếu hết hạn / chưa đăng nhập.
- `RegisterScreen`: Đăng ký tài khoản mới kèm kiểm tra tính hợp lệ phía client và hiển thị thông báo lỗi từ server.
- `LoginScreen`: Đăng nhập, liên kết sang đăng ký, lưu token cục bộ.
- `TaskListScreen`: Giao diện 3 tab phân loại rõ ràng:
  - **Của tôi:** Các công việc do chính người dùng tạo (`scope=created`).
  - **Được giao:** Các công việc được phân công phụ trách (`scope=assigned`).
  - **Được chia sẻ:** Các công việc được người khác chia sẻ quyền xem/sửa (`scope=shared`).
  - Đầy đủ trạng thái: Đang tải (Loading), Lỗi kèm nút Thử lại (Error & Retry), Rỗng (Empty), Kéo để làm mới (Pull-to-refresh).
- `TaskDetailScreen`: Hiển thị chi tiết tiêu đề, mô tả, hạn hoàn thành, vai trò của người dùng, người tạo, người phụ trách và danh sách chia sẻ.
- Các Badge chuẩn Material 3: Trạng thái (Chưa thực hiện, Đang thực hiện, Đã hoàn thành), Mức độ ưu tiên (Thấp, Trung bình, Cao).
- Nút Đăng xuất: Hộp thoại xác nhận, xóa token khỏi `SharedPreferences` và đưa về màn hình đăng nhập.

---

## 5. Dữ liệu thử nghiệm trên MongoDB Atlas (`task_manager`)

| Họ tên | Email | Mật khẩu | Vai trò thử nghiệm |
|---|---|---|---|
| Trần Nguyễn Đức | `duc.tran@taskmanager.com` | `password123` | Người dùng A (Tạo Task 1, 2; Được giao Task 3; Được chia sẻ Task 4) |
| Nguyễn Văn An | `an.nguyen@taskmanager.com` | `password123` | Người dùng B (Được giao Task 1; Tạo Task 3, 4) |
| Lê Thị Bình | `binh.le@taskmanager.com` | `password123` | Người dùng C (Được chia sẻ Task 1 với quyền viewer; Được giao Task 4) |

---

## 6. Phạm vi công việc còn lại (Dành cho Buổi 2 và Buổi 3)
- **Buổi 2:**
  - Hoàn thiện CRUD công việc: Thêm công việc mới (`POST /api/tasks`), Chỉnh sửa công việc (`PUT /api/tasks/:id`), Xóa công việc (`DELETE /api/tasks/:id`), Cập nhật nhanh trạng thái (`PATCH /api/tasks/:id/status`).
  - Nghiệp vụ Giao việc: Giao việc cho nhiều người (`/api/tasks/:id/assignees`), chỉ định người phụ trách chính.
  - Nghiệp vụ Chia sẻ: Chia sẻ quyền `viewer` / `editor`, thay đổi quyền, thu hồi quyền chia sẻ (`/api/tasks/:id/shares`).
- **Buổi 3:**
  - Email thông báo: Gửi email tự động khi giao việc/chia sẻ/hoàn thành (`emailService`, `email_logs`).
  - Thông báo trong ứng dụng: Collection `notifications`, đếm thông báo chưa đọc, đánh dấu đã đọc.
  - Tiện ích & Thống kê: Tìm kiếm công việc theo từ khóa, lọc theo trạng thái/ưu tiên, thống kê tiến độ (`/api/statistics`).

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
│   │   ├── controllers/             # authController, taskController, userController, assignmentController, taskShareController
│   │   ├── middleware/              # authMiddleware, permissionMiddleware, validateMiddleware, errorMiddleware
│   │   ├── models/                  # User.js, Task.js, TaskShare.js
│   │   ├── routes/                  # authRoutes, taskRoutes, userRoutes, assignmentRoutes, taskShareRoutes
│   │   ├── services/                # taskService.js (tập trung phân quyền getTaskPermissions)
│   │   ├── validators/              # authValidator.js, taskValidator.js
│   │   ├── app.js                   # Cấu hình Express app
│   │   └── server.js                # Khởi động server
│   ├── .env.example                 # Mẫu biến môi trường
│   ├── .gitignore                   # Loại trừ .env, node_modules
│   └── package.json
├── TaskManager/                     # Frontend Flutter Mobile Client
│   ├── android/app/src/debug/       # AndroidManifest.xml (usesCleartextTraffic)
│   ├── lib/
│   │   ├── models/                  # user.dart, task.dart, task_share.dart
│   │   ├── screens/
│   │   │   ├── auth/                # auth_gate.dart, login_screen.dart, register_screen.dart
│   │   │   ├── tasks/               # task_list_screen.dart, task_detail_screen.dart, task_create_screen.dart, task_edit_screen.dart
│   │   │   ├── assignment/          # assign_task_screen.dart
│   │   │   └── sharing/             # task_sharing_screen.dart
│   │   ├── services/                # api_client.dart, auth_service.dart, task_service.dart, user_service.dart, task_share_service.dart
│   │   ├── utils/                   # constants.dart, validators.dart, date_formatter.dart
│   │   ├── widgets/                 # task_card.dart, status_badge.dart, priority_badge.dart, loading_view.dart, user_selector.dart
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

## 4. Các chức năng và Endpoint đã hoàn thành (Buổi 1 & Buổi 2)

### 4.1. Nhóm A - Xác thực tài khoản
- `POST /api/auth/register`: Đăng ký tài khoản (validate fullName không rỗng, email hợp lệ, password >= 6 ký tự, băm bcryptjs, email trùng trả 409, không trả passwordHash).
- `POST /api/auth/login`: Đăng nhập bằng email và mật khẩu (sai email hoặc sai mật khẩu đều trả 401 cùng thông điệp `"Email hoặc mật khẩu không đúng"`, thành công trả JWT token và thông tin người dùng).
- `GET /api/auth/me`: Lấy thông tin tài khoản hiện tại từ JWT Bearer token (thiếu/sai/hết hạn trả 401).

### 4.2. Nhóm B & C - Quản lý công việc, Giao việc và Chia sẻ (Buổi 2)

#### Ma trận phân quyền hiệu lực (hợp các vai trò của người dùng trên công việc):
| Hành động | creator | editor (share) | assignee | viewer (share) | Người không liên quan |
|---|:---:|:---:|:---:|:---:|:---:|
| **Xem** (`GET /api/tasks/:id`) | Có | Có | Có | Có | 403 Forbidden |
| **Sửa thông tin** (`PUT /api/tasks/:id`) | Có | Có | Không | Không | 403 Forbidden |
| **Đổi trạng thái** (`PATCH /api/tasks/:id/status`) | Có | Có | Có | Không | 403 Forbidden |
| **Xóa công việc** (`DELETE /api/tasks/:id`) | Có | Không | Không | Không | 403 Forbidden |
| **Giao việc** (`assignees`) | Có | Không | Không | Không | 403 Forbidden |
| **Chia sẻ** (`shares`) | Có | Không | Không | Không | 403 Forbidden |

#### Chi tiết Endpoints:
- `POST /api/tasks`: Tạo công việc mới (`title` bắt buộc <= 200 ký tự, `priority`, `status`, `startDate`, `dueDate`; tự gán `createdBy`, bỏ qua các trường can thiệp quyền do client gửi).
- `GET /api/tasks`: Lấy danh sách công việc (`scope=created|assigned|shared`).
- `GET /api/tasks/:id`: Lấy chi tiết công việc kèm đối tượng permissions `{ canEdit, canChangeStatus, canDelete, canAssign, canShare }` phục vụ hiển thị nút tương tác trên app.
- `PUT /api/tasks/:id`: Cập nhật thông tin công việc (creator và editor; chỉ nhận `title, description, startDate, dueDate, priority, status`).
- `PATCH /api/tasks/:id/status`: Đổi trạng thái công việc (`todo`, `in_progress`, `completed`).
- `DELETE /api/tasks/:id`: Xóa công việc và cascade xóa toàn bộ bản ghi `TaskShare` liên quan (chỉ creator).
- `GET /api/users/search?q=`: Tìm kiếm người dùng theo tên hoặc email (trim >= 2 ký tự, thoát ký tự đặc biệt regex, giới hạn tối đa 10 kết quả, không trả `passwordHash`).
- `GET /api/users/:id`: Lấy thông tin công khai của người dùng theo ID (400 nếu sai định dạng, 404 nếu không tìm thấy).
- `GET /api/tasks/:id/assignees`: Lấy danh sách người được giao và người phụ trách chính.
- `POST /api/tasks/:id/assignees`: Giao việc cho nhiều người (`userIds`, `primaryAssigneeId`; gộp không trùng lặp, kiểm tra tồn tại nguyên tử).
- `PATCH /api/tasks/:id/assignees/:userId`: Chỉ định người phụ trách chính.
- `DELETE /api/tasks/:id/assignees/:userId`: Hủy giao việc (nếu là người phụ trách chính thì chuyển về `null`).
- `GET /api/tasks/:id/shares`: Lấy danh sách người được chia sẻ quyền.
- `POST /api/tasks/:id/shares`: Chia sẻ quyền `viewer` hoặc `editor` cho nhiều người (chặn chia sẻ cho creator 400, bỏ qua trùng lặp dựa trên unique index `taskId + userId`).
- `PATCH /api/tasks/:id/shares/:shareId`: Cập nhật quyền chia sẻ (`viewer` <-> `editor`).
- `DELETE /api/tasks/:id/shares/:shareId`: Thu hồi quyền chia sẻ.

### 4.3. Giao diện Flutter (Buổi 1 & Buổi 2)
- `AuthGate`: Tự động kiểm tra token lưu trong `SharedPreferences`, tự động đăng nhập khi mở lại app.
- `RegisterScreen`: Đăng ký tài khoản mới kèm kiểm tra tính hợp lệ phía client và hiển thị thông báo lỗi từ server.
- `LoginScreen`: Đăng nhập, liên kết sang đăng ký, lưu token cục bộ.
- `TaskListScreen`: 3 tab phân loại rõ ràng (Của tôi, Được giao, Được chia sẻ). Kèm trạng thái tải, lỗi tắt server có nút thử lại, kéo để làm mới, nút FloatingActionButton tạo công việc.
- `TaskCreateScreen`: Form tạo công việc mới (tiêu đề, mô tả, chọn ngày bắt đầu & hạn hoàn thành bằng `showDatePicker`, dropdown ưu tiên & trạng thái).
- `TaskEditScreen`: Form chỉnh sửa công việc đã điền sẵn dữ liệu cũ.
- `TaskDetailScreen`: Hiển thị chi tiết công việc, người tạo, người phụ trách chính, danh sách người được giao và chia sẻ. Các nút bấm hành động (Sửa, Đổi trạng thái, Giao việc, Chia sẻ, Xóa) tự động ẩn/hiện theo quyền `permissions` từ backend.
- `AssignTaskScreen`: Giao diện giao việc cho nhiều người bằng `UserSelector` (tìm kiếm debounce 400ms), chọn người phụ trách chính, hủy giao việc.
- `TaskSharingScreen`: Giao diện chia sẻ cho nhiều người, chọn quyền `viewer`/`editor`, cập nhật quyền và thu hồi quyền chia sẻ có hộp thoại xác nhận.
- Đầy đủ thông báo kết quả bằng SnackBar; tự động điều hướng về màn hình đăng nhập khi gặp lỗi 401.

---

## 5. Dữ liệu thử nghiệm trên MongoDB Atlas (`task_manager`)

| Họ tên | Email | Mật khẩu | Vai trò thử nghiệm |
|---|---|---|---|
| Trần Nguyễn Đức | `duc.tran@taskmanager.com` | `password123` | Người dùng A (Tạo Task 1, 2; Được giao Task 3; Được chia sẻ Task 4) |
| Nguyễn Văn An | `an.nguyen@taskmanager.com` | `password123` | Người dùng B (Được giao Task 1; Tạo Task 3, 4) |
| Lê Thị Bình | `binh.le@taskmanager.com` | `password123` | Người dùng C (Được chia sẻ Task 1 với quyền viewer; Được giao Task 4) |

---

## 6. Phạm vi công việc còn lại (Dành cho Buổi 3)
- **Email thông báo:** Gửi email tự động khi giao việc/chia sẻ/hoàn thành (`emailService`, `email_logs`).
- **Thông báo trong ứng dụng:** Collection `notifications`, đếm thông báo chưa đọc, đánh dấu đã đọc.
- **Tiện ích & Thống kê:** Tìm kiếm công việc theo từ khóa, lọc theo trạng thái/ưu tiên, thống kê tiến độ (`/api/statistics`).

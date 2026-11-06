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
│   │   ├── controllers/             # auth, task, user, assignment, taskShare, notification, emailLog, statistics
│   │   ├── middleware/              # authMiddleware, permissionMiddleware, validateMiddleware, errorMiddleware
│   │   ├── models/                  # User.js, Task.js, TaskShare.js, Notification.js, EmailLog.js, TaskActivity.js
│   │   ├── routes/                  # authRoutes, taskRoutes, userRoutes, assignmentRoutes, taskShareRoutes, notificationRoutes, statisticsRoutes
│   │   ├── services/                # taskService.js, notificationService.js, emailService.js
│   │   ├── utils/                   # emailTemplates.js
│   │   ├── validators/              # authValidator.js, taskValidator.js
│   │   ├── app.js                   # Cấu hình Express app
│   │   └── server.js                # Khởi động server
│   ├── .env.example                 # Mẫu biến môi trường
│   ├── .gitignore                   # Loại trừ .env, node_modules
│   └── package.json
├── TaskManager/                     # Frontend Flutter Mobile Client
│   ├── android/app/src/debug/       # AndroidManifest.xml (usesCleartextTraffic)
│   ├── lib/
│   │   ├── models/                  # user.dart, task.dart, task_share.dart, notification.dart, task_activity.dart, statistics.dart
│   │   ├── screens/
│   │   │   ├── auth/                # auth_gate.dart, login_screen.dart, register_screen.dart
│   │   │   ├── tasks/               # task_list_screen.dart, task_detail_screen.dart, task_create_screen.dart, task_edit_screen.dart
│   │   │   ├── assignment/          # assign_task_screen.dart
│   │   │   ├── sharing/             # task_sharing_screen.dart
│   │   │   ├── notifications/       # notification_screen.dart
│   │   │   └── profile/             # profile_screen.dart (hồ sơ, đổi mật khẩu, thống kê)
│   │   ├── services/                # api_client, auth, task, user, task_share, notification, statistics
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
# Cấu hình gửi email (nodemailer)
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_SECURE=false
SMTP_USER=your_email@gmail.com
SMTP_PASS=your_app_password
EMAIL_FROM=Task Manager <no-reply@taskmanager.com>
```
> **Lưu ý bảo mật:** File `.env` chứa mật khẩu cơ sở dữ liệu, JWT secret và mật khẩu ứng dụng email tuyệt đối không commit lên Git (đã được cấu hình trong `.gitignore`).
> Nếu chưa cấu hình SMTP, API vẫn hoạt động bình thường; email được ghi nhận ở trạng thái `failed` trong `email_logs` và không làm hỏng nghiệp vụ giao việc/chia sẻ.

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
- **Lưu ý về bảo mật mạng:** Giao tiếp HTTP không mã hóa tới `10.0.2.2` chỉ được cho phép ở bản debug thông qua `android:usesCleartextTraffic="true"`. Bản release (`flutter build apk --release`) chỉ khai báo quyền `android.permission.INTERNET` và yêu cầu API backend phải triển khai qua giao thức HTTPS có mã hóa để đảm bảo an toàn dữ liệu.
- **Chạy trên thiết bị thật (Physical Device):** Có thể ghi đè địa chỉ API bằng cờ `--dart-define`:
  ```bash
  flutter run --dart-define=API_URL=http://<ip-máy-tính>:3000/api
  ```
  (Yêu cầu máy tính và điện thoại kết nối cùng mạng Wi-Fi/LAN và cổng 3000 được tường lửa máy tính cho phép).

---

## 4. Các chức năng và Endpoint đã hoàn thành (Buổi 1, 2 & 3)

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
- `DELETE /api/tasks/:id`: Xóa công việc (chỉ creator); cascade xóa `TaskShare` và `TaskActivity`; giữ lại `Notification` và `EmailLog` để bảo toàn lịch sử kiểm toán (audit trail) theo yêu cầu chuẩn Đề bài mục 4. Khi người dùng mở thông báo của công việc đã bị xóa, ứng dụng hiển thị thông điệp rõ ràng và bộ đếm chưa đọc vẫn hoạt động chính xác.
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
- `TaskListScreen` (Buổi 3): Thanh tìm kiếm theo từ khóa, bộ lọc trạng thái/ưu tiên/người được giao, sắp xếp theo hạn hoàn thành/ưu tiên/ngày tạo/ngày cập nhật; huy hiệu số thông báo chưa đọc trên AppBar.
- `NotificationScreen` (Buổi 3): Danh sách thông báo trong ứng dụng, đánh dấu đã đọc từng thông báo hoặc tất cả, điều hướng nhanh tới công việc liên quan.
- `ProfileScreen` (Buổi 3): Xem/cập nhật họ tên và ảnh đại diện, đổi mật khẩu, xem thống kê công việc, giao việc và hạn hoàn thành.
- `TaskDetailScreen` (Buổi 3): Bổ sung mục "Lịch sử hoạt động" hiển thị người thực hiện, hành động, chi tiết thay đổi và thời gian.
- Đầy đủ thông báo kết quả bằng SnackBar; tự động điều hướng về màn hình đăng nhập khi gặp lỗi 401.

### 4.4. Nhóm D - Thông báo trong ứng dụng (Buổi 3)
- `GET /api/notifications`: Lấy danh sách thông báo của chính người dùng (mới nhất trước).
- `GET /api/notifications/unread-count`: Đếm số thông báo chưa đọc.
- `PATCH /api/notifications/:id/read`: Đánh dấu một thông báo đã đọc (chỉ chủ sở hữu).
- `PATCH /api/notifications/read-all`: Đánh dấu tất cả thông báo đã đọc.
- Tự động sinh thông báo khi: giao việc (`task_assigned`), chia sẻ (`task_shared`), đổi trạng thái (`task_status_changed`/`task_completed`), đổi hạn hoàn thành (`task_due_changed`). Người thực hiện hành động không nhận thông báo cho chính hành động đó; thông báo trùng trong thời gian ngắn được gộp.

### 4.5. Nhóm E - Gửi email thông báo (Buổi 3)
- Gửi email qua `nodemailer` khi: giao việc, chia sẻ công việc, đổi hạn hoàn thành, hoàn thành công việc.
- Mỗi lần gửi được ghi vào `email_logs` với trạng thái `pending`/`sent`/`failed`, số lần thử và lỗi (nếu có). Lỗi email không làm hỏng thao tác chính.
- `GET /api/tasks/:id/email-logs`: Xem lịch sử email của công việc (chỉ người tạo - creator mới có quyền truy cập; người khác nhận 403 Forbidden).
- `POST /api/email-logs/:logId/retry`: Gửi lại email thất bại (chỉ creator, tối đa 5 lần thử).

### 4.6. Nhóm E & F - Thống kê và Lịch sử hoạt động
- `GET /api/statistics/tasks`: Tổng số công việc người dùng có quyền truy cập, phân bố theo trạng thái (`todo`, `in_progress`, `completed`) và ưu tiên (`low`, `medium`, `high`). Người chưa có công việc nào nhận toàn số 0.
- `GET /api/statistics/assignments`: Tổng số việc được giao, số việc là người phụ trách chính (`primaryAssignee`), phân bố theo trạng thái.
- `GET /api/statistics/deadlines`: Thống kê hạn hoàn thành công việc:
  - **Định nghĩa quá hạn (`overdue`):** `dueDate < hiện tại` và trạng thái khác `completed` (công việc đã hoàn thành không tính là quá hạn).
  - **Định nghĩa sắp đến hạn (`dueSoon` / `upcoming`):** `hiện tại <= dueDate <= hiện tại + days * 24h` và trạng thái khác `completed` (không tính việc đã hoàn thành hoặc đã quá hạn).
  - **Tham số `days`:** Nhận số nguyên từ 1 đến 30 (mặc định là 3 ngày). Nếu truyền `days` ngoài khoảng 1-30 hoặc không hợp lệ, API trả về `400 Bad Request`.
  - **Giới hạn danh sách:** Mảng `overdue` và `upcoming` được giới hạn tối đa 10 mục mới nhất.
  - **Ví dụ phản hồi:**
    ```json
    {
      "message": "Lay thong ke han hoan thanh thanh cong",
      "days": 3,
      "windowHours": 72,
      "overdueCount": 1,
      "upcomingCount": 2,
      "dueSoonCount": 2,
      "overdue": [
        {
          "id": "672465e99876543210abcdef",
          "title": "Hoàn thiện báo cáo",
          "status": "in_progress",
          "priority": "high",
          "dueDate": "2026-11-04T10:00:00.000Z"
        }
      ],
      "upcoming": [
        {
          "id": "672465e99876543210abcdee",
          "title": "Kiểm thử hệ thống",
          "status": "todo",
          "priority": "medium",
          "dueDate": "2026-11-08T17:00:00.000Z"
        }
      ]
    }
    ```
- `GET /api/tasks/:id/activities`: Lịch sử hoạt động của công việc, sắp xếp theo thứ tự mới nhất trước (`createdAt: -1`). Ghi nhận các hành động: `created`, `updated`, `status_changed`, `assigned`, `unassigned`, `primary_changed`, `shared`, `share_updated`, `share_revoked`. Người lạ không có quyền xem công việc bị từ chối với `403 Forbidden`.
- `GET /api/tasks` hỗ trợ bộ lọc: `q` (tìm theo tiêu đề), `status`, `priority`, `assigneeId`, `sortBy` (`dueDate|priority|createdAt|updatedAt`), `order` (`asc|desc`).

### 4.7. Nhóm G - Hồ sơ cá nhân và lịch sử hoạt động (Buổi 3)
- `PUT /api/auth/me`: Cập nhật `fullName` (bắt buộc, <= 100 ký tự) và `avatarUrl` (tùy chọn, <= 500 ký tự). Không cho đổi email qua endpoint này.
- `PUT /api/auth/change-password`: Đổi mật khẩu, kiểm tra mật khẩu hiện tại, mật khẩu mới >= 6 ký tự và khác mật khẩu cũ.
- `GET /api/tasks/:id/activities`: Lịch sử hoạt động của công việc (yêu cầu quyền xem), ghi nhận các hành động `created`, `updated`, `status_changed`, `assigned`, `unassigned`, `primary_changed`, `shared`, `share_updated`, `share_revoked`.

---

## 5. Dữ liệu thử nghiệm trên MongoDB Atlas (`task_manager`)

| Họ tên | Email | Mật khẩu | Vai trò thử nghiệm |
|---|---|---|---|
| Trần Nguyễn Đức | `duc.tran@taskmanager.com` | `password123` | Người dùng A (Tạo Task 1, 2; Được giao Task 3; Được chia sẻ Task 4) |
| Nguyễn Văn An | `an.nguyen@taskmanager.com` | `password123` | Người dùng B (Được giao Task 1; Tạo Task 3, 4) |
| Lê Thị Bình | `binh.le@taskmanager.com` | `password123` | Người dùng C (Được chia sẻ Task 1 với quyền viewer; Được giao Task 4) |

---

## 6. Tổng kết Buổi 3
- **Đã hoàn thành:** Thông báo trong ứng dụng, gửi email qua nodemailer kèm `email_logs` và gửi lại, tìm kiếm/lọc/sắp xếp công việc, thống kê công việc - giao việc - hạn hoàn thành, hồ sơ cá nhân, đổi mật khẩu và lịch sử hoạt động công việc.
- **Quyết định thiết kế:**
  - Quyền hạn được kiểm tra tập trung ở backend (`getTaskPermissions` + `requireTaskPermission`); giao diện chỉ ẩn/hiện nút theo `permissions` trả về, không thay thế kiểm tra phía server.
  - "Sắp đến hạn" được định nghĩa là hạn hoàn thành trong vòng 24 giờ tới và không tính công việc đã hoàn thành.
  - Sắp xếp theo ưu tiên dùng thứ tự logic low < medium < high; công việc không có hạn hoàn thành luôn xếp cuối.
  - Gửi email thất bại chỉ ghi log `failed`, không rollback thao tác giao việc/chia sẻ/đổi hạn/hoàn thành.
  - Xóa công việc cascade cả `TaskShare`, `TaskActivity`, `Notification`, `EmailLog` để tránh dữ liệu mồ côi.
- **Kiểm thử:** Đã chạy `flutter analyze` (không lỗi), `flutter test` (12 test pass), kiểm thử API với 4 vai trò (creator, assignee, editor, viewer) và người không liên quan, kiểm thử trên Android Emulator.
- **Lưu ý môi trường:** Phiên làm việc không truy cập được MongoDB MCP nên việc kiểm tra dữ liệu Atlas được thực hiện gián tiếp qua API và script Mongoose cục bộ; không thực hiện thao tác xóa database/collection/cluster.
- **Hạn chế còn lại:** Cần cấu hình SMTP thật trong `api/.env` để gửi email ra ngoài; môi trường kiểm thử đã dùng SMTP sink cục bộ.

---

## 7. Quy trình Git và Báo cáo Minh bạch
- **Giai đoạn 0 (Khởi tạo dự án):** Các commit khởi tạo cấu trúc ban đầu được đẩy trực tiếp lên `main` (`7b20468` khởi tạo repository & README, `7a1fa75` khởi tạo Node.js API, `cf40102` khởi tạo Flutter App) theo yêu cầu thiết lập ban đầu "commit đầu tiên là push đầu tiên".
- **Sửa lỗi biên dịch Kotlin:** Có 01 commit nóng trực tiếp trên `main` (`53b1e89`: `fix(app): tat incremental compilation kotlin tranh loi khac o dia`) để giải quyết triệt để lỗi biên dịch chéo ổ đĩa trên Windows khi chạy `flutter run`.
- **Phân nhánh Nhóm E (Thống kê):** Chức năng thống kê ban đầu được cài đặt trong nhánh `d-thong-bao-email` (tại commit `ebee89b` và `d43138d`). Sau đợt kiểm toán độc lập, nhánh chuyên biệt `e-thong-ke` đã được khởi tạo để bổ sung toàn diện bộ kiểm thử tích hợp (`node --test` trong `api/tests/`), kiểm thử widget Flutter (`statistics_test.dart`) và tài liệu kỹ thuật chi tiết.

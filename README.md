# TDMU Điểm Danh

Ứng dụng điểm danh cho Trường Đại học Thủ Dầu Một: sinh viên điểm danh bằng
**nhận diện khuôn mặt chạy ngay trên điện thoại**, kết hợp **vị trí GPS** và
**mã phiên có thời hạn** để chống điểm danh hộ. Giảng viên và Viện quản lý lớp,
sự kiện, thống kê trên điện thoại hoặc trên web.

| | |
|---|---|
| 📱 **Tải ứng dụng Android (APK)** | [Trang Releases](https://github.com/unclefour-work/TDMU_DIEMDANH_APP/releases/latest) |
| 🌐 **Bản web cho Giảng viên / Viện** | https://unclefour-work.github.io/TDMU_DIEMDANH_APP/ |

> Ứng dụng **không có chức năng tự tạo tài khoản**. Tài khoản do nhà trường cấp;
> đăng nhập bằng **Mã số** và **Mật khẩu**.

---

## Mục lục

1. [Cài đặt nhanh cho người dùng](#1-cài-đặt-nhanh-cho-người-dùng)
2. [Chức năng theo vai trò](#2-chức-năng-theo-vai-trò)
3. [Cách hệ thống chống gian lận](#3-cách-hệ-thống-chống-gian-lận)
4. [Hướng dẫn sử dụng](#4-hướng-dẫn-sử-dụng)
5. [Dành cho lập trình viên](#5-dành-cho-lập-trình-viên)
6. [Bảo mật](#6-bảo-mật)
7. [Câu hỏi thường gặp](#7-câu-hỏi-thường-gặp)

---

## 1. Cài đặt nhanh cho người dùng

### Điện thoại Android (Sinh viên, Giảng viên, Viện)

1. Mở [trang Releases](https://github.com/unclefour-work/TDMU_DIEMDANH_APP/releases/latest)
   bằng điện thoại và tải file `.apk`.
2. Mở file vừa tải. Nếu máy hỏi, cho phép "Cài đặt ứng dụng không rõ nguồn gốc"
   cho trình duyệt đang dùng.
3. Mở app, cấp quyền **Camera** và **Vị trí** khi được hỏi.
4. Đăng nhập bằng Mã số và Mật khẩu được cấp.

Yêu cầu: Android 7.0 trở lên, chip ARM (hầu hết điện thoại hiện nay), camera
trước, GPS, có kết nối Internet.

### Web (chỉ Giảng viên và Viện)

Mở https://unclefour-work.github.io/TDMU_DIEMDANH_APP/ bằng Chrome hoặc Edge
rồi đăng nhập. Sinh viên không đăng nhập được trên web vì việc điểm danh cần
nhận diện khuôn mặt trên điện thoại.

---

## 2. Chức năng theo vai trò

| Vai trò | Chức năng | Điện thoại | Web |
|---|---|:-:|:-:|
| **Sinh viên** | Đăng ký khuôn mặt, điểm danh lớp học, điểm danh sự kiện (QR / mã), lịch sử, thống kê, xin nghỉ phép, thông báo | ✅ | — |
| **Giảng viên** | Tạo phiên điểm danh, quản lý lớp, nhập danh sách sinh viên từ Excel, xuất điểm danh ra Excel, duyệt nghỉ phép, thống kê, gửi thông báo | ✅ | ✅ |
| **Viện** | Tạo mã sự kiện (QR + mã 6 ký tự), quản lý và thống kê sự kiện, xuất Excel, duyệt tài khoản và yêu cầu đổi thông tin, mở/khoá quyền cập nhật khuôn mặt | ✅ | ✅ |

---

## 3. Cách hệ thống chống gian lận

Một lượt điểm danh chỉ hợp lệ khi qua được tất cả các lớp sau:

| Lớp | Kiểm tra |
|---|---|
| Khuôn mặt | Khuôn mặt quét được phải khớp với khuôn mặt đã đăng ký của **chính tài khoản đang đăng nhập** |
| Chống giả mạo | Phát hiện ảnh in, ảnh/video phát lại trên màn hình (không cần người dùng làm động tác) |
| Vị trí | Phải đứng trong bán kính cho phép quanh vị trí lớp học / sự kiện |
| Thời gian | Phiên điểm danh và mã sự kiện chỉ có hiệu lực trong khoảng thời gian đã đặt |

Toàn bộ phần nhận diện chạy **trên thiết bị** bằng ONNX Runtime, ảnh khuôn mặt
không gửi lên máy chủ:

1. Google ML Kit phát hiện khuôn mặt và 5 điểm mốc.
2. Căn chỉnh khuôn mặt về kích thước 112×112.
3. Hai mô hình MiniFASNet kiểm tra khuôn mặt thật / giả.
4. Bộ lọc chất lượng (kích thước, góc mặt, độ nét, độ sáng).
5. MobileFaceNet trích vector đặc trưng 512 chiều.
6. So khớp cosine với dữ liệu đã đăng ký (ngưỡng 0.40, có kiểm tra khoảng cách
   giữa kết quả tốt nhất và kết quả thứ hai).

---

## 4. Hướng dẫn sử dụng

### 4.1 Sinh viên

**Đăng ký khuôn mặt (bắt buộc ở lần đăng nhập đầu tiên)**

1. Đọc và đồng ý với thông báo thu thập dữ liệu khuôn mặt.
2. Làm theo 5 bước hướng dẫn: nhìn thẳng, quay trái, quay phải, ngẩng lên,
   cúi xuống. App tự chụp khi mặt đúng tư thế và giữ yên.
3. Nên thực hiện ở nơi đủ sáng, không đeo khẩu trang, không ngược sáng.

Muốn đăng ký lại khuôn mặt về sau thì cần Viện mở quyền cập nhật.

**Điểm danh lớp học**

1. Trang chủ → **Điểm Danh Lớp Học**. App hiện các lớp đang có phiên điểm danh.
2. Chọn lớp → quét khuôn mặt → app kiểm tra vị trí.
3. Kết quả: **Có mặt** nếu trong thời gian của phiên, **Trễ** nếu trong vòng
   30 phút sau khi phiên kết thúc.

**Điểm danh sự kiện**

1. Trang chủ → **Điểm Danh Sự Kiện**, quét mã QR của sự kiện hoặc nhập mã 6 ký tự.
2. App kiểm tra thời hạn mã, vị trí, rồi quét khuôn mặt.

**Khác:** xem lịch sử, thống kê chuyên cần, gửi đơn xin nghỉ phép (kèm ảnh minh
chứng), nhận thông báo từ giảng viên, cập nhật ảnh đại diện.

### 4.2 Giảng viên

- **Tạo phiên điểm danh:** chọn lớp, đặt thời lượng và bán kính, lấy vị trí hiện
  tại hoặc chọn trên bản đồ.
- **Danh sách lớp học:** tạo lớp, xem chi tiết từng buổi, cập nhật vị trí lớp.
- **Nhập sinh viên từ Excel (.xlsx):** dòng đầu là tiêu đề; từ dòng 2, cột B là
  **Họ tên**, cột C là **Mã số sinh viên**.
- **Xuất Excel:** bảng điểm danh của cả lớp theo từng buổi. Trên điện thoại file
  lưu vào thư mục Download, trên web trình duyệt tải file xuống.
- **Duyệt nghỉ phép**, **Thống kê lớp học**, **Gửi thông báo** cho lớp.

### 4.3 Viện

- **Tạo mã sự kiện:** sinh mã QR và mã 6 ký tự có thời hạn, kèm vị trí và bán kính.
- **Danh sách / Thống kê sự kiện:** xem người đã check-in, xuất Excel.
- **Quản lý tài khoản:** duyệt tài khoản, duyệt yêu cầu đổi thông tin cá nhân.
- **Quyền cập nhật khuôn mặt:** mở cho toàn bộ sinh viên hoặc mở riêng một lần
  cho từng sinh viên.

---

## 5. Dành cho lập trình viên

### Công nghệ

- Flutter 3.41 / Dart 3.11 (Android, Web)
- Firebase Authentication (email + mật khẩu) và Cloud Firestore
- ONNX Runtime, Google ML Kit Face Detection
- Google Maps (Android), OpenStreetMap qua `flutter_map` (Web)

### Cấu hình bắt buộc trước khi build

Kho mã này **không chứa** cấu hình Firebase hay API key. Bạn cần dùng project
Firebase của riêng mình:

1. Tạo project Firebase, bật **Authentication → Email/Password** và **Firestore**.
2. Sinh file cấu hình:
   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```
   Lệnh này tạo `lib/firebase_options.dart` và `android/app/google-services.json`.
   Hai file này đã nằm trong `.gitignore`, **đừng đưa lên git**.
   (Có thể xem cấu trúc mẫu ở `lib/firebase_options.example.dart`.)
3. Bản Android dùng Google Maps: sao chép `.env.example` thành `.env` rồi điền
   key của bạn vào `MAPS_API_KEY` (bật "Maps SDK for Android"). Gradle tự đọc
   file này khi build. `.env` đã nằm trong `.gitignore`, **đừng đưa lên git**.
   Bản web dùng OpenStreetMap nên không cần key.
4. Tạo các chỉ mục Firestore:
   ```bash
   firebase deploy --only firestore:indexes
   ```
5. Viết Firestore Security Rules phù hợp với hệ thống của bạn trước khi dùng thật
   (xem mục [Bảo mật](#6-bảo-mật)).

### Tạo tài khoản

App không có màn hình đăng ký. Với mỗi người dùng:

1. Tạo user trong Firebase Authentication (email + mật khẩu).
2. Tạo document `users/{uid}` với các trường:

   | Trường | Ý nghĩa |
   |---|---|
   | `name` | Họ tên |
   | `maSo` | Mã số dùng để đăng nhập |
   | `email` | Email đã tạo ở bước 1 |
   | `role` | `student`, `teacher` hoặc `institute` |
   | `approved` | `true` thì mới đăng nhập được |

### Chạy và build

```bash
flutter pub get
flutter run                      # chạy trên điện thoại đang cắm
flutter build apk --release      # build/app/outputs/flutter-apk/app-release.apk
flutter run -d chrome            # chạy thử bản web
flutter build web --release      # build/web
```

Lưu ý:

- Thư viện ONNX Runtime chỉ có bản cho chip ARM, nên nhận diện khuôn mặt không
  chạy trên máy ảo x86_64. Hãy thử phần này trên điện thoại thật.
- Lấy vị trí trên web chỉ hoạt động với `https://` hoặc `localhost`.

### Bản web trên GitHub Pages

Bản web được build và đưa lên GitHub Pages tự động bằng GitHub Actions
(`.github/workflows/deploy-web.yml`) mỗi khi nhánh `main` thay đổi. Bản build
không được commit vào repo.

Workflow lấy cấu hình Firebase từ secret `FIREBASE_OPTIONS_DART_B64` của repo:
nội dung file `lib/firebase_options.dart` (chỉ cần phần `web`) mã hoá base64.
Đặt secret tại **Settings → Secrets and variables → Actions**, và chọn
**Settings → Pages → Source: GitHub Actions**.

### Cấu trúc thư mục

```
lib/
├── main.dart
├── platform/          # tách phần khác nhau giữa điện thoại và web
│   ├── student_gateway*.dart   # phần sinh viên (ONNX) không biên dịch cho web
│   ├── platform_files*.dart    # lưu file: thư mục Download / tải xuống
│   └── web_frame.dart          # căn giữa giao diện trên màn hình rộng
├── screens/
│   ├── login_screen.dart
│   ├── Student/       # điểm danh, đăng ký khuôn mặt, lịch sử, nghỉ phép
│   ├── teacher/       # phiên điểm danh, lớp học, duyệt nghỉ phép, thông báo
│   ├── institute/     # sự kiện, duyệt tài khoản, quyền cập nhật khuôn mặt
│   └── profile/
├── services/
│   ├── face_service.dart       # toàn bộ pipeline nhận diện trên thiết bị
│   ├── face_quality_filter.dart
│   └── excel_*_service.dart
└── widgets/
assets/models/         # các mô hình ONNX
```

Màn hình dùng chung (đăng nhập, hồ sơ) không import thẳng màn hình sinh viên mà
đi qua `lib/platform/student_gateway.dart`; nếu không bản web sẽ không build được.

### Mô hình

| File | Vai trò | Đầu vào |
|---|---|---|
| `mbf_sa_kd_fp32.onnx` | Trích đặc trưng khuôn mặt (MobileFaceNet, 512 chiều) | 112×112 RGB |
| `2_7_80x80_MiniFASNetV2.onnx`, `4_0_0_80x80_MiniFASNetV1SE.onnx` | Chống giả mạo | 80×80 BGR |
| `mask_detector.onnx` | Phát hiện khẩu trang khi đăng ký | 224×224 RGB |

Khi đổi mô hình nhận diện (kể cả bản lượng tử hoá khác), toàn bộ sinh viên phải
đăng ký lại khuôn mặt vì vector cũ không còn so khớp được.

---

## 6. Bảo mật

- **Không đưa key lên git.** `.env` (key Google Maps),
  `lib/firebase_options.dart` và `android/app/google-services.json` phải nằm
  ngoài kho mã; kho này chỉ có file mẫu `.env.example` và
  `lib/firebase_options.example.dart`.
- **Cấu hình Firebase nằm trong mọi file APK và bản web** (ai cũng giải nén ra
  xem được). Vì vậy an toàn của dữ liệu phụ thuộc vào Firestore Security Rules,
  không phụ thuộc vào việc giấu key.
- Nên **tắt tự đăng ký** trong Firebase Console (Authentication → Settings →
  User actions) vì app không dùng chức năng này.
- Nên **giới hạn API key** trong Google Cloud Console: key Android chỉ cho đúng
  tên gói và chữ ký của app, key Maps chỉ cho đúng API cần dùng.
- Dữ liệu khuôn mặt lưu dưới dạng vector số, không lưu ảnh.

---

## 7. Câu hỏi thường gặp

**App báo "Tài khoản đang chờ Viện duyệt".**
Tài khoản chưa được duyệt. Liên hệ Viện.

**Quét khuôn mặt mãi không được.**
Ra nơi đủ sáng, bỏ khẩu trang và kính râm, giữ điện thoại ngang tầm mắt, để mặt
nằm gọn trong khung.

**App báo đang ở ngoài phạm vi.**
Bật GPS ở chế độ chính xác cao, ra chỗ thoáng và chờ vài giây rồi thử lại.

**Đăng nhập web báo chỉ dành cho Giảng viên và Viện.**
Tài khoản sinh viên chỉ dùng được trên app điện thoại.

**Không thấy lớp nào để điểm danh.**
Giảng viên chưa mở phiên, phiên đã hết hạn, hoặc mã số của bạn chưa có trong
danh sách lớp.

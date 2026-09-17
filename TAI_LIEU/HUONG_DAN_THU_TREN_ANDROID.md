# Thử BE 3D Site Viewer trên Android

## Trước hết, nói thẳng về file .apk

**Tôi chưa cấp được file `.apk`.** Không phải vì ngại, mà vì máy chủ nơi tôi đang chạy **không có Android SDK và không kết nối được tới `dl.google.com` / `storage.googleapis.com`** — nên không tải được cả Flutter SDK lẫn Android SDK để biên dịch. Tôi đã kiểm tra trực tiếp chứ không đoán:

```
java, javac        → có
gradle             → có
Android SDK, aapt  → KHÔNG có
dl.google.com      → không kết nối được
storage.googleapis.com → không kết nối được
```

Thiếu Android SDK thì Gradle không thể tạo ra `.apk`, dù có Java.

Có hai đường để bạn thử ngay hôm nay. Đường 1 dùng được trong vài phút.

---

## Đường 1 — Chạy thẳng file HTML trên điện thoại (khuyên dùng để thử trước)

File `be3d_simulator.html` tự nhận biết màn hình điện thoại: bỏ khung máy giả, chạy full màn hình, nút bấm to lên cho vừa ngón tay. Trên Chrome Android nó có gần đủ mọi thứ:

| Tính năng | Trên Chrome Android |
|---|---|
| Chọn file `.glb` từ máy | Chạy |
| Kiểm tra file (bắt Draco…) | Chạy |
| Hiển thị 3D, xoay/zoom | Chạy |
| Ghi chú gắn toạ độ, xuất JSON/CSV | Chạy |
| Chế độ đi bộ + tâm ngắm | Chạy |
| Ẩn/hiện theo nhóm vật liệu | Chạy |
| **Quét QR bằng camera** | Chạy — Chrome Android có sẵn `BarcodeDetector` |
| **La bàn xoay theo hướng máy** | Chạy, nhưng xem lưu ý bên dưới |

### Cách làm

1. Chép `be3d_simulator.html` sang điện thoại (cáp USB, Zalo, Google Drive, email…), để trong thư mục `Download`.
2. Mở app **Files / Quản lý tệp** trên máy → bấm vào file → chọn mở bằng **Chrome**.
3. Chép luôn file `.glb` sang máy, rồi trong app bấm **Chọn file .glb**.

### Muốn chạy hoàn toàn offline ngoài công trường

Mặc định trang lấy thư viện hiển thị 3D từ mạng. Muốn không cần mạng, tải sẵn hai file rồi để **cùng thư mục** với file HTML:

- `model-viewer.min.js` — tải từ trang chủ model-viewer (bản 3.5.0)
- `qrcode.min.js` — thư viện vẽ QR (chỉ cần nếu muốn tạo mã QR trên điện thoại)

Trang đã được sửa để **ưu tiên bản đặt cạnh file HTML**, không có mới hỏi tới mạng. Chép cả thư mục sang điện thoại là xong — từ đó không cần mạng nữa.

### Lưu ý về la bàn và camera

Chrome chỉ cho dùng **cảm biến hướng** và **camera** khi trang chạy ở "ngữ cảnh an toàn". Mở bằng `file://` đôi khi bị chặn. Nếu bấm 🧭 La bàn hoặc 📷 Quét QR mà không lên, làm cách này:

- Trên máy tính, mở thư mục chứa file rồi chạy `npx http-server -p 8080` (hoặc `python -m http.server 8080`).
- Điện thoại và máy tính nối **cùng Wi-Fi**, mở trên điện thoại: `http://<địa-chỉ-IP-máy-tính>:8080/be3d_simulator.html`
- Cách này còn cho phép **Thêm vào màn hình chính** để có icon như app thật.

Đây là cách nhanh nhất để trả lời ba câu chỉ máy thật mới trả lời được: la bàn có xoay đúng hướng không, quét QR ngoài nắng có bắt được mã không, và ẩn theo nhóm vật liệu có đủ dùng không.

---

## Đường 2 — Tự build `.apk` trên máy bạn

Bạn đã cài sẵn Flutter + Android Studio từ hướng dẫn lúc đầu, nên máy bạn build được. Nhưng **bộ Flutter hiện tại (v2.1) mới chỉ có phần xem mô hình** — chưa có ghi chú, mốc QR, đi bộ, la bàn, lọc. Những thứ đó đang nằm trong bản HTML.

Cách port hợp lý nhất là **không viết lại từ đầu**: đóng gói chính bản HTML này thành tài sản trong app Flutter, rồi dùng WebView hiển thị. Như vậy toàn bộ phần đã kiểm chứng qua 205 ca test được giữ nguyên, chỉ cần lớp vỏ Flutter lo việc chọn file và lưu ghi chú xuống bộ nhớ máy.

Khi bạn muốn, tôi làm bộ Flutter đó và gửi nguyên bộ để bạn chạy:

```
flutter pub get
flutter build apk --release
```

File `.apk` sẽ nằm ở `build\app\outputs\flutter-apk\app-release.apk`.

---

## Tóm lại

Thử Đường 1 trước — nhanh, không phải build gì, và đủ để biết ba thứ quan trọng nhất có chạy ngoài hiện trường không. Có kết quả rồi hẵng bỏ công làm APK, vì lúc đó mình biết chắc đang đóng gói một thứ dùng được.

# BE 3D Site Viewer — bộ dựng APK (v3)

## Nói thẳng trước: tôi không tạo được file `.apk` từ đây

Máy tôi đang chạy **không có Android SDK** và **không ra được Internet**. Tôi kiểm lại chứ không đoán:

```
java, javac, gradle        → có
flutter, dart, adb, aapt   → KHÔNG có
Android SDK                → KHÔNG có
dl.google.com              → 000 (không kết nối được)
storage.googleapis.com     → 000
services.gradle.org        → 000
pub.dev                    → 000
```

Thiếu Android SDK thì không có gì tạo ra được `.apk`, và không có mạng thì không tải về được.

**Nên tôi làm cách tốt nhất còn lại:** viết sẵn toàn bộ project và một script chạy **một lệnh** trên máy bạn — máy bạn có Flutter và có mạng. Script tự dựng khung, tự chép code, **tự tải hộ hai thư viện JavaScript** (việc mà tôi không làm được), rồi tự build ra APK.

---

## Chạy

### Windows

```powershell
cd <thư mục này>
.\chuan_bi.ps1
```

### macOS / Linux

```bash
bash chuan_bi.sh
```

Xong, file APK nằm ở:

```
app\build\app\outputs\flutter-apk\app-release.apk
```

Chép sang điện thoại, bấm vào để cài. Android sẽ hỏi *"cài ứng dụng từ nguồn không xác định"* → chọn Cho phép.

Muốn dừng lại trước bước build (để tự chạy `flutter run` qua cáp USB):

```powershell
.\chuan_bi.ps1 -KhongBuild        # Windows
bash chuan_bi.sh --khong-build    # macOS/Linux
```

---

## App này là gì

Vỏ Flutter **rất mỏng** bọc quanh chính file `be3d_simulator.html` đã qua **361 ca test**. Không viết lại tính năng nào — viết lại là mất hết hiệu lực của bộ test đó.

| Phần | Ai làm |
|---|---|
| Kiểm file, hiển thị 3D, ghi chú, mốc QR, đi bộ, la bàn, ẩn/hiện nhóm | Trang HTML (đã test) |
| Chọn file bằng trình chọn của Android | Flutter |
| Lưu ghi chú xuống bộ nhớ máy | Flutter |
| Xuất JSON/CSV ra file thật | Flutter |
| Xin quyền camera | Kotlin (`MainActivity.kt`) |
| Phục vụ trang cho WebView | Flutter (máy chủ nội bộ) |

### Vì sao phải có máy chủ nội bộ, không dùng `loadFlutterAsset`

Cách hiển nhiên là nạp trang qua `file:///android_asset/...`. Cách đó **hỏng vì ba lý do độc lập**, mỗi lý do đủ giết một tính năng:

1. `<model-viewer>` nạp bằng `<script type="module">`, mà module từ `file://` bị **CORS chặn thẳng** (origin là `null`). Lỗi này tôi đã **quan sát được** khi chạy thử bằng Chromium, không phải suy đoán. Không có model-viewer thì màn hình trắng.
2. **La bàn và camera chỉ chạy trong "ngữ cảnh an toàn".** Theo chuẩn W3C Secure Contexts, dải `127.0.0.0/8` được coi là đáng tin cậy — nên `http://127.0.0.1` đủ điều kiện, còn `file://` trong WebView Android thì không. (Dùng thẳng số `127.0.0.1` chứ không dùng chữ `localhost`: chuẩn ghi rõ `localhost` chỉ đáng tin khi trình duyệt tuân thủ luật phân giải tên riêng.)
3. `fetch()` file `.glb` cũng vướng đúng luật CORS ở mục 1.

Máy chủ chỉ nghe trên loopback. Nhưng app khác trong cùng máy vẫn gọi được `127.0.0.1`, nên mọi đường dẫn nằm sau **một chuỗi bí mật sinh ngẫu nhiên mỗi lần chạy** — có test riêng cho việc này.

### App **không** xin quyền Internet

`AndroidManifest.xml` cố ý **không khai** `android.permission.INTERNET`. Mô hình công trình của bạn không thể rời khỏi máy, và bạn **tự kiểm chứng được** điều đó bằng cách mở file manifest ra xem — không phải tin lời tôi.

---

## Đã kiểm được gì, chưa kiểm được gì

### Đã kiểm bằng code chạy thật

**43 ca test** cho lớp cầu nối (`test_cau_noi.mjs`) — đây là phần rủi ro nhất của cả app. Toàn bộ thiết kế dựa trên một giả định: rằng **bọc ngoài** được các hàm của trang mà không sửa một ký tự nào trong `index.html`. Nếu giả định đó sai, app vẫn chạy, vẫn hiện mô hình, nhưng ghi chú không lưu, xuất file không ra file, nút chọn file không làm gì — **toàn lỗi hỏng âm thầm**.

Cách kiểm: dựng lại **đúng logic máy chủ Dart** bằng Node (cùng đường dẫn, cùng chuỗi bí mật, cùng cách chèn script), giả lập kênh JavaScript của `webview_flutter`, chạy thật trong Chromium. Mã cầu nối được **trích thẳng từ `lib/cau_noi_js.dart`**, không chép tay.

Đáng chú ý trong đó:

- Cả hai nút chọn file đều gọi được Android, và **không còn** mở hộp thoại của WebView
- Ghi chú thêm/xoá đều tự lưu, và bọc ngoài **không làm mất giá trị trả về** của hàm gốc
- Nội dung xuất file qua kênh **y nguyên văn** — so sánh bằng nhau tuyệt đối với chuỗi chứa dấu nháy, xuống dòng, gạch ngược, tiếng Việt, emoji
- Dữ liệu ghi chú hỏng → bỏ qua, **không làm sập trang và không mất ghi chú đang có**
- Nút Quay lại đóng mô hình trước, chỉ thoát app khi đã ở màn hình chính
- Truy cập không đúng chuỗi bí mật → bị từ chối

Cộng với **361 ca** của trang HTML → **404 ca, tất cả đạt**.

### Chưa kiểm được (không có Flutter/Dart trên máy này)

Code Dart **chưa từng được biên dịch**. Tôi kiểm được những gì kiểm được:

- Viết một bộ quét cú pháp Dart (`kiem_dart.py`) đọc đúng chuỗi thô `r'''...'''`, chuỗi ba nháy và nội suy `${}` lồng nhau → cả 5 file đều nhất quán ngoặc
- **Và kiểm chính bộ kiểm đó**: cố tình làm hỏng file theo 4 kiểu (thiếu ngoặc đóng, thừa ngoặc đóng, chuỗi không đóng, import thiếu dấu chấm phẩy) → bắt được cả 4. (Ban đầu tôi đếm bằng biểu thức chính quy và nó **báo sai 2 file** vì hiểu nhầm `//` trong `'http://127.0.0.1'` là chú thích. Công cụ kiểm mà tự nó sai thì tệ hơn không kiểm, vì nó làm mình đi sửa code đúng.)
- `bash -n` cho script shell, kiểm XML hợp lệ cho manifest

Nhưng **cân bằng ngoặc không phải biên dịch**. Sai kiểu, sai tên hàm, sai chữ ký API thì chỉ `flutter build` mới biết. Nếu build báo lỗi, gửi tôi nguyên văn thông báo.

### Chữ ký API — đã tra tài liệu, không đoán

Đúng bài học từ ba lần sai chữ ký hàm bên pyRevit, tôi tra tài liệu cho từng thứ trước khi gọi:

| API | Nguồn đã tra |
|---|---|
| `WebViewController(onPermissionRequest:)`, `addJavaScriptChannel`, `loadRequest`, `runJavaScriptReturningResult` | tài liệu `webview_flutter` |
| `WebViewPermissionResourceType.camera`, `request.grant()/deny()` | tài liệu `WebViewPermissionRequest` |
| `PopScope(onPopInvokedWithResult:)` | tài liệu Flutter — `onPopInvoked` **đã bị đánh dấu lỗi thời** sau 3.22 |
| `FilePicker.pickFiles()` | changelog `file_picker` — **bản 11 đổi từ `FilePicker.platform.pickFiles()` sang hàm static**. Đúng loại bẫy đã dính ba lần trước |
| `127.0.0.1` là ngữ cảnh an toàn | chuẩn W3C Secure Contexts |

---

## Nếu build báo lỗi

### `pub get` không giải được `file_picker: ^11.0.0`

Flutter trên máy bạn cũ hơn yêu cầu của bản 11. Sửa **hai dòng**:

1. `pubspec.yaml`: đổi `file_picker: ^11.0.0` → `file_picker: ^8.0.0`
2. `lib/main.dart`: đổi `FilePicker.pickFiles(` → `FilePicker.platform.pickFiles(`

(Hoặc chạy `flutter upgrade` rồi thử lại — cách này gọn hơn.)

### `onPopInvokedWithResult` không tồn tại

Flutter cũ hơn 3.22. Trong `lib/main.dart` đổi `onPopInvokedWithResult: (didPop, _)` → `onPopInvoked: (didPop)`.

### Mở app ra thấy màn hình "⛔ Thiếu thư viện hiển thị 3D"

Đúng như thiết kế — app **cố ý dừng ở đó** thay vì để bạn phát hiện màn hình trắng giữa công trường. Nghĩa là `assets/www/model-viewer.min.js` chưa có. Chạy lại script, hoặc tải tay:

```
https://ajax.googleapis.com/ajax/libs/model-viewer/3.5.0/model-viewer.min.js
```

đặt vào `app/assets/www/model-viewer.min.js` rồi build lại.

### Quét QR: camera đen

Thử theo thứ tự: (1) kiểm quyền camera trong Cài đặt → Ứng dụng; (2) nếu vẫn đen, thêm vào `pubspec.yaml` dòng `webview_flutter_android: ^4.0.0`, rồi trong `lib/main.dart` thêm sau khi tạo controller:

```dart
if (c.platform is AndroidWebViewController) {
  (c.platform as AndroidWebViewController)
      .setMediaPlaybackRequiresUserGesture(false);
}
```

(Tôi cố ý **không** đưa sẵn vào: nút quét được bấm bằng tay nên đã có "cử chỉ người dùng", theo lý thuyết là đủ. Thêm một phụ thuộc nữa chỉ để phòng xa thì không đáng, vì mỗi phụ thuộc là một chỗ có thể lệch phiên bản.)

### Không tìm thấy `MainActivity.kt`

Script sẽ báo cảnh báo và bỏ qua. Hậu quả: **không xin được quyền camera → không quét được QR**. Phần xem mô hình vẫn chạy bình thường. Báo tôi biết cấu trúc thư mục `android/app/src/main` để tôi sửa script.

---

## Ba câu hỏi cần bạn trả lời ngoài công trường

Đây là lý do làm APK này. Chỉ máy thật ngoài hiện trường mới trả lời được, và cả ba đều đang chặn quyết định tiếp theo:

1. **La bàn có xoay đúng hướng giữa thép và cốt thép không?** — Nay bớt quan trọng: phép căn 3 mốc của mức 3 đã bỏ được la bàn. Nhưng vẫn cần biết cho phương án dự phòng.
2. **Quét QR ngoài nắng gắt có bắt được mã không?** — **Quan trọng nhất.** Toàn bộ quy trình cắm mốc phụ thuộc câu này.
3. **Ẩn/hiện theo nhóm vật liệu có đủ dùng không, hay bắt buộc phải ẩn từng cấu kiện?** — Câu này quyết định có phải bỏ `model-viewer` hay không.

Thêm một việc nhỏ mà rất đáng làm khi đã có APK: mở file `.glb` thật của bạn, xem ô xanh **"Phải xác nhận TRƯỚC khi cắm mốc"** báo đơn vị là gì. Nếu nó nghi mm hoặc feet thì biết ngay trước khi in mốc.

---

## Cấu trúc bộ này

```
chuan_bi.ps1 / chuan_bi.sh    script dựng + build (chạy cái này)
pubspec.yaml                  khai báo 3 thư viện
lib/
  main.dart                   vỏ app, quyền, vòng đời
  may_chu_noi_bo.dart         máy chủ HTTP trên 127.0.0.1
  cau_noi_js.dart             mã JavaScript nối trang web với Dart
  luu_tru.dart                lưu ghi chú, ghi file xuất
  kiem_tra_cai_dat.dart       chặn màn hình trắng khi thiếu thư viện
assets/www/index.html         BẢN SAO ĐÚNG NGUYÊN VĂN của be3d_simulator.html
ghep_vao_project/             manifest, cấu hình mạng, MainActivity.kt mẫu
test_cau_noi.mjs              43 ca test cho lớp cầu nối
kiem_dart.py                  bộ quét cú pháp Dart
TAI_LIEU/                     thiết kế mức 3, bảng rà soát quy trình
```

Chạy lại test cầu nối (cần Node + Playwright):

```
node test_cau_noi.mjs
python3 kiem_dart.py
```

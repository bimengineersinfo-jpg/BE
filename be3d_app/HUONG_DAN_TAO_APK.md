# Hướng dẫn tạo file APK

Dành cho Windows. Toàn bộ mất khoảng **15–25 phút lần đầu**, phần lớn là ngồi đợi Gradle tải về.

---

## Bước 0 — Kiểm máy đã sẵn sàng chưa (2 phút)

Mở **PowerShell** rồi gõ:

```powershell
flutter doctor
```

Cần **hai dòng có dấu ✓**:

```
[✓] Flutter (Channel stable, ...)
[✓] Android toolchain - develop for Android devices
```

Những dòng khác (Chrome, Visual Studio, VS Code) **không cần** — chúng ta chỉ build Android.

**Nếu dòng Android toolchain có dấu ✗ hoặc !**, đọc kỹ nó nói thiếu gì:

| Nó nói | Gõ lệnh này |
|---|---|
| `Android license status unknown` hoặc `Some Android licenses not accepted` | `flutter doctor --android-licenses` rồi gõ `y` cho tới hết |
| `Unable to locate Android SDK` | Mở Android Studio → Settings → Languages & Frameworks → Android SDK → cài **Android SDK Command-line Tools** |
| `cmdline-tools component is missing` | Như trên, cài đúng gói **Android SDK Command-line Tools (latest)** |

Gõ lại `flutter doctor` cho tới khi hai dòng trên đều ✓.

---

## Bước 1 — Giải nén và chạy script (1 lệnh)

Giải nén `BE3D_APK_v4.zip`. Trong đó có thư mục `be3d_app`. Mở PowerShell **ngay tại thư mục đó**:

> Mẹo: mở thư mục `be3d_app` trong File Explorer, bấm vào thanh địa chỉ, gõ `powershell` rồi Enter.

```powershell
.\chuan_bi.ps1
```

Nếu Windows chặn với thông báo *"running scripts is disabled on this system"*, gõ lệnh này trước rồi chạy lại:

```powershell
Set-ExecutionPolicy -Scope Process -Bypass
```

(Lệnh đó chỉ có tác dụng trong cửa sổ PowerShell đang mở, đóng cửa sổ là hết — không đổi gì vĩnh viễn trên máy.)

### Script sẽ in ra 6 bước

```
[0] Kiem tra Flutter              -> OK Flutter 3.x.x
[1] Tao bo khung Flutter          -> OK Da tao
[2] Chep code va cau hinh         -> 5 dòng OK
[3] Tai thu vien JavaScript       -> OK model-viewer.min.js (khoảng 300000 byte)
[4] flutter pub get               -> OK
[5] flutter build apk --release   -> đợi 5–15 phút lần đầu
```

Xong sẽ hiện khung xanh:

```
===============================================
 XONG. File APK:
 ...\be3d_app\app\build\app\outputs\flutter-apk\app-release.apk
 (xx MB)
===============================================
```

**Nếu script dừng giữa chừng với chữ đỏ `DUNG LAI:`** — đó là script cố ý dừng chứ không phải nó hỏng. Đọc phần "Khi gặp lỗi" ở cuối.

---

## Bước 2 — Cài lên điện thoại

1. Chép file `app-release.apk` sang điện thoại (cáp USB, Zalo, Google Drive, email — cách nào cũng được).
2. Trên điện thoại mở **Files / Quản lý tệp**, bấm vào file `.apk`.
3. Android sẽ hỏi *"cài ứng dụng từ nguồn không xác định"* → chọn **Cài đặt / Cho phép**.
4. Mở app **BE 3D Site Viewer**.

---

## Bước 3 — Thử ngay 5 việc này

Làm theo đúng thứ tự, mỗi việc chỉ 1–2 phút. Nếu việc nào không được thì dừng ở đó và báo tôi.

**1. Mở file `.glb` thật của anh.** Chép file vào thư mục `Download` của máy trước, rồi trong app bấm **Chọn file .glb**. (Chọn thẳng từ Google Drive có thể không cho đường dẫn thật.)

**2. Xem ô xanh "Phải xác nhận TRƯỚC khi cắm mốc".** Nó đoán đơn vị file của anh là gì. Đây là việc đáng làm nhất trước khi ra công trường — biết trước file tính bằng mét hay feet.

**3. Đo tỷ lệ.** Bấm **📏 Đo tỷ lệ**, chạm hai điểm mà anh biết chắc khoảng cách thật (hai trục cột chẳng hạn), gõ số mét vào. App sẽ nói file này tính bằng đơn vị gì. **Làm ngay tại văn phòng được, không cần ra công trường.**

**4. Thử chế độ đi bộ và la bàn.** Bấm **🚶 Đi bộ**, rồi bấm **🧭 La bàn**. Xoay người xem mô hình có xoay theo không — đây là câu hỏi mà chỉ máy thật trả lời được.

**5. Ngoài công trường: cắm mốc.** Bấm **📍 Cắm mốc**, đứng tại chân một cột, chạm đúng điểm đó trên mô hình. Đi ra xa **ít nhất 20 m**, cắm mốc thứ hai. Cắm thêm mốc thứ ba ở chỗ khác nữa để app đo được sai số thật.

> **Thử phá hoại luôn cho chắc:** cắm hai mốc chỉ cách nhau 2 m — app **phải** hiện ô đỏ cảnh báo. Nếu không hiện thì có gì đó sai, báo tôi.

---

## Khi gặp lỗi

### Script dừng ở bước 0: `KHONG TIM THAY 'flutter'`

Flutter chưa có trong PATH. Đóng PowerShell, mở lại, gõ `flutter --version`. Vẫn không được thì quay lại hướng dẫn cài Flutter.

### Script dừng ở bước 3: không tải được `model-viewer.min.js`

Mạng chặn hoặc chậm. Tự tải bằng trình duyệt:

```
https://ajax.googleapis.com/ajax/libs/model-viewer/3.5.0/model-viewer.min.js
```

Lưu vào `be3d_app\app\assets\www\model-viewer.min.js` (file phải khoảng **300 KB**, nếu chỉ vài KB là tải nhầm trang). Rồi chạy lại `.\chuan_bi.ps1`.

### Script dừng ở bước 4: `pub get` không giải được `file_picker`

Flutter trên máy cũ hơn yêu cầu. Cách nhanh nhất:

```powershell
flutter upgrade
```

rồi chạy lại script. Nếu không muốn nâng cấp Flutter thì sửa **hai dòng**:

1. `be3d_app\pubspec.yaml`: đổi `file_picker: ^11.0.0` → `file_picker: ^8.0.0`
2. `be3d_app\lib\main.dart`: đổi `FilePicker.pickFiles(` → `FilePicker.platform.pickFiles(`

Rồi xoá thư mục `be3d_app\app` và chạy lại script.

### Bước 5 báo lỗi Gradle hoặc Java

Lỗi hay gặp nhất là bản Java không khớp Gradle. Thử:

```powershell
cd app
flutter clean
flutter build apk --release
```

Vẫn lỗi thì **chụp lại toàn bộ phần chữ đỏ** và gửi tôi. Đừng đoán — thông báo lỗi của Gradle nói rất rõ nguyên nhân, tôi đọc là biết.

### Muốn xem lỗi rõ hơn: cắm cáp chạy thẳng

Cách này cho thấy log ngay lúc app chạy, tìm lỗi nhanh hơn build APK nhiều:

1. Trên điện thoại: Cài đặt → Giới thiệu → bấm **Số bản dựng** 7 lần để mở Tuỳ chọn nhà phát triển.
2. Bật **Gỡ lỗi qua USB**.
3. Cắm cáp vào máy tính, điện thoại hỏi thì chọn **Cho phép**.
4. Trên máy tính:

```powershell
cd app
flutter devices          # phải thấy tên điện thoại của anh
flutter run
```

App sẽ tự cài và chạy, mọi lỗi hiện thẳng trong PowerShell.

### Mở app ra thấy màn hình `⛔ Thiếu thư viện hiển thị 3D`

Đây là app **cố ý dừng**, không phải hỏng — để anh không gặp màn hình trắng giữa công trường. Nghĩa là bước 3 của script chưa tải được thư viện. Xem mục ở trên.

### Chạy lại từ đầu cho sạch

```powershell
Remove-Item -Recurse -Force app
.\chuan_bi.ps1
```

---

## Nếu muốn build lại sau khi tôi gửi bản mới

Chỉ cần chép đè file mới rồi:

```powershell
cd app
flutter build apk --release
```

Không phải chạy lại script (script chỉ cần cho lần đầu).

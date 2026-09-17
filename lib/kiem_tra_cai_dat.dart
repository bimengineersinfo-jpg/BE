import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

/// Kết quả kiểm tra trước khi mở WebView.
class KetQuaKiemTra {
  final bool coModelViewer;
  final bool coQrcode;
  final int coModelViewerByte;
  final String? loi;

  const KetQuaKiemTra({
    required this.coModelViewer,
    required this.coQrcode,
    required this.coModelViewerByte,
    this.loi,
  });

  bool get chayDuoc => coModelViewer;
}

/// ---------------------------------------------------------------------------
/// VÌ SAO PHẢI KIỂM TRƯỚC
/// ---------------------------------------------------------------------------
/// `model-viewer.min.js` là thư viện vẽ 3D. Không có nó thì app mở lên, chọn
/// file, kiểm file xong hết — rồi màn hình xem mô hình TRẮNG TRƠN, không báo
/// gì. Đúng cái lỗi mà cả dự án này bắt đầu từ đó.
///
/// Trang HTML có sẵn phương án dự phòng là tải từ Internet, nhưng ngoài công
/// trường không có mạng, nên dự phòng đó vô dụng đúng lúc cần nhất.
///
/// Nên: kiểm ngay lúc khởi động, và nếu thiếu thì hiện màn hình hướng dẫn rõ
/// ràng thay vì để người dùng đi tới màn hình trắng. Kiểm bằng NỘI DUNG chứ
/// không chỉ bằng việc file có tồn tại hay không — vì bộ này có kèm sẵn một
/// file giữ chỗ, mà file giữ chỗ thì cũng "tồn tại".
/// ---------------------------------------------------------------------------
Future<KetQuaKiemTra> kiemTraCaiDat() async {
  int co = 0;
  bool mv = false;
  String? loi;
  try {
    final d = await rootBundle.load('assets/www/model-viewer.min.js');
    co = d.lengthInBytes;
    // Thư viện thật nặng khoảng 300 KB và luôn có lời gọi đăng ký web component.
    // Kiểm hai dấu hiệu độc lập, không tin mỗi kích thước.
    if (co > 80 * 1024) {
      final dau = utf8.decode(
        d.buffer.asUint8List(d.offsetInBytes, d.lengthInBytes),
        allowMalformed: true,
      );
      mv = dau.contains('customElements') && dau.contains('model-viewer');
    }
  } catch (e) {
    loi = 'Không đọc được assets/www/model-viewer.min.js ($e)';
  }

  bool qr = false;
  try {
    final d = await rootBundle.load('assets/www/qrcode.min.js');
    qr = d.lengthInBytes > 2 * 1024;
  } catch (_) {
    qr = false;
  }

  return KetQuaKiemTra(
    coModelViewer: mv,
    coQrcode: qr,
    coModelViewerByte: co,
    loi: loi,
  );
}

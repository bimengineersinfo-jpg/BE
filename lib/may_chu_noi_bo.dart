import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;

import 'cau_noi_js.dart';

/// ---------------------------------------------------------------------------
/// MÁY CHỦ NỘI BỘ — vì sao BẮT BUỘC phải có, không phải cho sang
/// ---------------------------------------------------------------------------
/// Cách hiển nhiên nhất là nạp trang bằng `loadFlutterAsset()`, tức là mở qua
/// `file:///android_asset/...`. Cách đó HỎNG vì ba lý do độc lập nhau, mỗi lý
/// do đủ để làm chết một tính năng:
///
///   1. `<model-viewer>` được nạp bằng `<script type="module">`. Trình duyệt
///      áp luật CORS cho module, mà `file://` có origin là `null` nên bị chặn
///      thẳng. Lỗi này ĐÃ QUAN SÁT ĐƯỢC khi chạy thử bằng Chromium:
///        "Access to script at 'file:///.../model-viewer.min.js' from origin
///         'null' has been blocked by CORS policy"
///      Không có model-viewer thì không có gì hiện lên cả.
///
///   2. La bàn (`DeviceOrientationEvent`) và camera (`getUserMedia`) chỉ chạy
///      trong "ngữ cảnh an toàn". Theo chuẩn W3C Secure Contexts, dải
///      127.0.0.0/8 được coi là đáng tin cậy — nên `http://127.0.0.1` ĐỦ điều
///      kiện, còn `file://` trong WebView Android thì không.
///      (Dùng thẳng số 127.0.0.1 chứ KHÔNG dùng chữ "localhost": chuẩn ghi rõ
///      "localhost" chỉ đáng tin khi trình duyệt tuân thủ luật phân giải tên
///      riêng, còn dải loopback thì luôn đúng.)
///
///   3. `fetch()` file .glb cũng vướng đúng luật CORS ở mục 1.
///
/// Máy chủ chỉ nghe trên loopback nên không ra khỏi máy. Nhưng app khác trong
/// cùng điện thoại vẫn gọi được 127.0.0.1, nên mọi đường dẫn đều nằm sau một
/// chuỗi bí mật sinh ngẫu nhiên mỗi lần chạy.
/// ---------------------------------------------------------------------------
class MayChuNoiBo {
  HttpServer? _server;
  late final String _token = _sinhToken();

  /// File .glb đang mở. Đọc theo LUỒNG chứ không nạp hết vào RAM — mô hình
  /// công trình có thể vài trăm MB, nạp cả vào bộ nhớ là đủ để hệ điều hành
  /// giết app mà không báo gì.
  String? _duongDanModel;
  Uint8List? _byteModel; // chỉ dùng khi trình chọn file không trả về đường dẫn

  final Map<String, Uint8List> _demAsset = {};

  bool get dangChay => _server != null;
  int get cong => _server?.port ?? 0;

  /// Địa chỉ trang chủ, đã kèm chuỗi bí mật.
  String get diaChiGoc => 'http://127.0.0.1:$cong/$_token/';

  static String _sinhToken() {
    final r = Random.secure();
    return List.generate(16, (_) => r.nextInt(256))
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  Future<void> khoiDong() async {
    if (_server != null) return;
    // Cổng 0 = để hệ điều hành tự chọn cổng còn trống.
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0, shared: false);
    _server!.listen(_xuLy, onError: (Object e) {/* bỏ qua, không làm sập app */});
  }

  Future<void> dung() async {
    await _server?.close(force: true);
    _server = null;
  }

  void datModelTheoDuongDan(String duongDan) {
    _duongDanModel = duongDan;
    _byteModel = null;
  }

  void datModelTheoByte(Uint8List bytes) {
    _byteModel = bytes;
    _duongDanModel = null;
  }

  Future<void> _xuLy(HttpRequest req) async {
    final res = req.response;
    try {
      final cacDoan = req.uri.pathSegments;
      // Chặn mọi truy cập không mang đúng chuỗi bí mật.
      if (cacDoan.isEmpty || cacDoan.first != _token) {
        res.statusCode = HttpStatus.notFound;
        await res.close();
        return;
      }
      final duong = cacDoan.skip(1).join('/');

      // Không cho đi ngược lên thư mục cha.
      if (duong.contains('..')) {
        res.statusCode = HttpStatus.forbidden;
        await res.close();
        return;
      }

      res.headers.set('Cache-Control', 'no-store');

      if (duong.isEmpty || duong == 'index.html') {
        await _traTrangChu(res);
        return;
      }
      if (duong == kTenFileCauNoi) {
        _datKieu(res, 'text/javascript; charset=utf-8');
        res.add(utf8.encode(kMaCauNoiJs));
        await res.close();
        return;
      }
      if (duong == 'model.glb') {
        await _traModel(res);
        return;
      }
      await _traAsset(res, duong);
    } catch (_) {
      try {
        res.statusCode = HttpStatus.internalServerError;
        await res.close();
      } catch (_) {}
    }
  }

  void _datKieu(HttpResponse res, String kieu) {
    res.headers.set(HttpHeaders.contentTypeHeader, kieu);
  }

  /// Trang chủ = ĐÚNG NGUYÊN VĂN file `be3d_simulator.html`, chỉ chèn thêm một
  /// thẻ script cầu nối ngay trước `</body>`.
  ///
  /// Cố ý không sửa file HTML: nó đang được 361 ca test kiểm, mà các test đó
  /// cắt code THẲNG TỪ file này ra. Sửa file là mất hiệu lực của cả bộ test.
  /// Cầu nối chỉ bọc ngoài các hàm sẵn có, không đụng vào bên trong.
  Future<void> _traTrangChu(HttpResponse res) async {
    final html = await _docAssetChu('assets/www/index.html');
    const the = '<script src="$kTenFileCauNoi"></script>';
    final viTri = html.lastIndexOf('</body>');
    final ra = viTri >= 0
        ? '${html.substring(0, viTri)}$the\n${html.substring(viTri)}'
        : '$html\n$the';
    _datKieu(res, 'text/html; charset=utf-8');
    res.add(utf8.encode(ra));
    await res.close();
  }

  Future<void> _traModel(HttpResponse res) async {
    _datKieu(res, 'model/gltf-binary');
    if (_duongDanModel != null) {
      final f = File(_duongDanModel!);
      if (!await f.exists()) {
        res.statusCode = HttpStatus.notFound;
        await res.close();
        return;
      }
      res.headers.contentLength = await f.length();
      await res.addStream(f.openRead());
      await res.close();
      return;
    }
    if (_byteModel != null) {
      res.headers.contentLength = _byteModel!.length;
      res.add(_byteModel!);
      await res.close();
      return;
    }
    res.statusCode = HttpStatus.notFound;
    await res.close();
  }

  Future<void> _traAsset(HttpResponse res, String duong) async {
    final khoa = 'assets/www/$duong';
    try {
      final bytes = _demAsset[khoa] ?? await _docAssetByte(khoa);
      _demAsset[khoa] = bytes;
      _datKieu(res, _kieuTheoDuoi(duong));
      res.headers.contentLength = bytes.length;
      res.add(bytes);
      await res.close();
    } catch (_) {
      // Thiếu file thì trả 404 rõ ràng. Trang HTML đã có sẵn phương án dự
      // phòng cho qrcode.min.js (hiện nguyên văn nội dung mốc để copy).
      res.statusCode = HttpStatus.notFound;
      await res.close();
    }
  }

  static String _kieuTheoDuoi(String duong) {
    final d = duong.toLowerCase();
    if (d.endsWith('.js')) return 'text/javascript; charset=utf-8';
    if (d.endsWith('.css')) return 'text/css; charset=utf-8';
    if (d.endsWith('.html')) return 'text/html; charset=utf-8';
    if (d.endsWith('.json')) return 'application/json; charset=utf-8';
    if (d.endsWith('.glb')) return 'model/gltf-binary';
    if (d.endsWith('.gltf')) return 'model/gltf+json';
    if (d.endsWith('.png')) return 'image/png';
    if (d.endsWith('.jpg') || d.endsWith('.jpeg')) return 'image/jpeg';
    if (d.endsWith('.svg')) return 'image/svg+xml';
    if (d.endsWith('.wasm')) return 'application/wasm';
    return 'application/octet-stream';
  }

  Future<Uint8List> _docAssetByte(String khoa) async {
    final d = await rootBundle.load(khoa);
    return d.buffer.asUint8List(d.offsetInBytes, d.lengthInBytes);
  }

  Future<String> _docAssetChu(String khoa) async {
    return utf8.decode(await _docAssetByte(khoa));
  }
}

import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'cau_noi_js.dart';
import 'kiem_tra_cai_dat.dart';
import 'luu_tru.dart';
import 'may_chu_noi_bo.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AppBE3D());
}

class AppBE3D extends StatelessWidget {
  const AppBE3D({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BE 3D Site Viewer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF1A73E8),
      ),
      home: const ManHinhChinh(),
    );
  }
}

class ManHinhChinh extends StatefulWidget {
  const ManHinhChinh({super.key});

  @override
  State<ManHinhChinh> createState() => _ManHinhChinhState();
}

class _ManHinhChinhState extends State<ManHinhChinh> {
  static const MethodChannel _kenhQuyen = MethodChannel('be3d/quyen');

  final MayChuNoiBo _mayChu = MayChuNoiBo();
  final LuuTru _luuTru = LuuTru();

  WebViewController? _dieuKhien;
  KetQuaKiemTra? _kiemTra;
  String? _loiKhoiDong;
  bool _dangTai = true;
  bool _dangMoFile = false;

  @override
  void initState() {
    super.initState();
    _khoiDong();
  }

  @override
  void dispose() {
    _mayChu.dung();
    super.dispose();
  }

  Future<void> _khoiDong() async {
    try {
      final kt = await kiemTraCaiDat();
      if (!mounted) return;
      setState(() => _kiemTra = kt);
      if (!kt.chayDuoc) {
        setState(() => _dangTai = false);
        return;
      }

      await _mayChu.khoiDong();

      final c = WebViewController(
        // Quyền camera cho việc quét mã QR. WebView hỏi -> ta đồng ý, NHƯNG
        // chỉ đồng ý sau khi chính app đã xin được quyền của hệ điều hành,
        // vì thiếu quyền cấp app thì getUserMedia vẫn hỏng.
        onPermissionRequest: (request) async {
          final canCamera =
              request.types.contains(WebViewPermissionResourceType.camera);
          if (canCamera) {
            final duoc = await _xinQuyenCamera();
            if (!duoc) {
              await request.deny();
              _bao('Chưa có quyền camera nên không quét được mã QR. '
                  'Vào Cài đặt → Ứng dụng → BE 3D Site Viewer → Quyền để bật.');
              return;
            }
          }
          await request.grant();
        },
      )
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(const Color(0xFFF4F6F9))
        ..addJavaScriptChannel(kTenKenh, onMessageReceived: _nhanTuTrang)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (_) {
              if (mounted) setState(() => _dangTai = false);
            },
            onWebResourceError: (err) {
              // Lỗi tải phụ (ví dụ CDN không với tới được khi offline) là
              // bình thường và trang đã có dự phòng. Chỉ báo khi hỏng khung
              // chính, tức là chính trang không mở được.
              if (err.isForMainFrame == true) {
                _bao('Không mở được trang: ${err.description}');
              }
            },
            // Chặn mọi điều hướng ra ngoài máy chủ nội bộ. App này chạy
            // offline, không có lý do gì để trang đi ra Internet.
            onNavigationRequest: (nav) {
              return nav.url.startsWith(_mayChu.diaChiGoc)
                  ? NavigationDecision.navigate
                  : NavigationDecision.prevent;
            },
          ),
        );

      await c.loadRequest(Uri.parse(_mayChu.diaChiGoc));
      if (!mounted) return;
      setState(() => _dieuKhien = c);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loiKhoiDong = '$e';
        _dangTai = false;
      });
    }
  }

  Future<bool> _xinQuyenCamera() async {
    if (!Platform.isAndroid) return true;
    try {
      final ok = await _kenhQuyen.invokeMethod<bool>('xinCamera');
      return ok ?? false;
    } on MissingPluginException {
      // MainActivity.kt chưa được chép đè. Vẫn cho chạy để không chặn oan;
      // nếu thiếu quyền thật thì getUserMedia sẽ báo lỗi ở trang web.
      return true;
    } catch (_) {
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Nhận lệnh từ trang web
  // ---------------------------------------------------------------------------
  Future<void> _nhanTuTrang(JavaScriptMessage tin) async {
    Map<String, dynamic> m;
    try {
      m = jsonDecode(tin.message) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    switch (m['cmd'] as String?) {
      case 'chonFile':
        await _chonFile((m['maDuAn'] as String?));
        break;
      case 'daMoViewer':
        await _napGhiChuDaLuu(
          (m['file'] ?? '') as String,
          (m['co'] as num?)?.toInt() ?? 0,
        );
        break;
      case 'luuHoSoMoc':
        await _luuTru.luuHoSoMoc(
          (m['file'] ?? '') as String,
          (m['co'] as num?)?.toInt() ?? 0,
          (m['json'] ?? '{}') as String,
        );
        break;
      case 'luuDsDuAn':
        await _luuTru.luuDsDuAn((m['json'] ?? '[]') as String);
        break;
      case 'luuCaiDatDuAn':
        await _luuTru.luuCaiDatDuAn(
          (m['maDuAn'] ?? '') as String,
          (m['json'] ?? '{}') as String,
        );
        break;
      case 'moDuAn':
        await _moDuAn((m['maDuAn'] ?? '') as String);
        break;
      case 'luuGhiChu':
        await _luuTru.luuGhiChu(
          (m['file'] ?? '') as String,
          (m['co'] as num?)?.toInt() ?? 0,
          (m['json'] ?? '{}') as String,
        );
        break;
      case 'xuatFile':
        await _xuatFile(
          (m['ten'] ?? 'be3d.txt') as String,
          (m['noiDung'] ?? '') as String,
        );
        break;
      case 'loi':
        _bao((m['msg'] ?? 'Lỗi không rõ') as String);
        break;
      case 'trangSanSang':
        await _napDsDuAn();
        break;
    }
  }

    Future<void> _chonFile(String? maDuAn) async {
    if (_dangMoFile) return;
    _dangMoFile = true;
    try {
      final ket = await FilePicker.platform.pickFiles(type: FileType.any);
      if (ket == null || ket.files.isEmpty) return;
      final f = ket.files.first;

      if (f.path != null && f.path!.isNotEmpty) {
        _mayChu.datModelTheoDuongDan(f.path!);
        if (maDuAn != null && maDuAn.isNotEmpty) {
          await _luuTru.luuDuongDanDuAn(maDuAn, f.path!);
        }
      } else if (f.bytes != null) {
        _mayChu.datModelTheoByte(f.bytes!);
      } else {
        _bao('Không lấy được nội dung file. Hãy chép file .glb vào bộ nhớ máy '
            '(ví dụ thư mục Download) rồi chọn lại từ đó, đừng chọn thẳng từ '
            'Google Drive hay OneDrive.');
        return;
      }

      final ten = f.name.isEmpty ? 'model.glb' : f.name;
      await _dieuKhien?.runJavaScript(
        'BE3D_moFile(${_chuoiJs('${_mayChu.diaChiGoc}model.glb')}, ${_chuoiJs(ten)})',
      );
    } catch (e) {
      _bao('Không mở được trình chọn file: $e');
    } finally {
      _dangMoFile = false;
    }
  }

  Future<void> _napDsDuAn() async {
    if (_dieuKhien == null) return;
    final json = await _luuTru.docDsDuAn();
    if (json != null) {
      await _dieuKhien!.runJavaScript('BE3D_napDsDuAn(${_chuoiJs(json)})');
    }
  }

  Future<void> _moDuAn(String maDuAn) async {
    if (maDuAn.isEmpty || _dieuKhien == null) return;
    final cd = await _luuTru.docCaiDatDuAn(maDuAn);
    if (cd != null) {
      await _dieuKhien!.runJavaScript(
        'BE3D_napCaiDatDuAn(${_chuoiJs(maDuAn)}, ${_chuoiJs(cd)})',
      );
    }
    final duong = await _luuTru.docDuongDanDuAn(maDuAn);
    if (duong != null) {
      _mayChu.datModelTheoDuongDan(duong);
      final ten = duong.split(Platform.pathSeparator).last;
      await _dieuKhien!.runJavaScript(
        'BE3D_moFile(${_chuoiJs('${_mayChu.diaChiGoc}model.glb')}, ${_chuoiJs(ten)})',
      );
    }
  }

  Future<void> _napGhiChuDaLuu(String ten, int soByte) async {
    if (_dieuKhien == null) return;
    final json = await _luuTru.docGhiChu(ten, soByte);
    if (json != null) {
      await _dieuKhien!.runJavaScript('BE3D_napGhiChu(${_chuoiJs(json)})');
    }
    // Hồ sơ mốc: chỉ chứa toạ độ TRONG MÔ HÌNH và tỷ lệ, nên dùng lại được
    // ở mọi lần mở app. Toạ độ ARCore thì không lưu — gốc toạ độ ARCore dựng
    // mới mỗi phiên nên số cũ vô nghĩa.
    final hs = await _luuTru.docHoSoMoc(ten, soByte);
    if (hs != null) {
      await _dieuKhien!.runJavaScript('BE3D_napHoSoMoc(${_chuoiJs(hs)})');
    }
  }

  Future<void> _xuatFile(String ten, String noiDung) async {
    try {
      final duong = await _luuTru.xuatFile(ten, noiDung);
      _bao('Đã lưu: $duong', lau: true);
    } catch (e) {
      _bao('Không ghi được file: $e');
    }
  }

  /// Đưa một chuỗi Dart vào câu lệnh JavaScript cho an toàn.
  /// Dùng jsonEncode chứ không tự ghép dấu nháy: nội dung ghi chú có thể chứa
  /// dấu nháy, xuống dòng, tiếng Việt — ghép tay là vỡ câu lệnh.
  static String _chuoiJs(String s) => jsonEncode(s);

  void _bao(String chu, {bool lau = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(chu),
        duration: Duration(seconds: lau ? 8 : 4),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  Future<void> _quayLai() async {
    final c = _dieuKhien;
    if (c == null) {
      if (mounted) SystemNavigator.pop();
      return;
    }
    // Hỏi trang web xem còn gì để đóng không. Chỉ khi trang bảo "thoat" mới
    // thoát hẳn — bấm Quay lại giữa lúc đang xem mô hình mà app tắt luôn thì
    // rất khó chịu ngoài công trường.
    try {
      final r = await c.runJavaScriptReturningResult('BE3D_quayLai()');
      final s = r.toString().replaceAll('"', '');
      if (s != 'thoat') return;
    } catch (_) {}
    if (mounted) SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _quayLai();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6F9),
        body: SafeArea(child: _than()),
      ),
    );
  }

  Widget _than() {
    if (_loiKhoiDong != null) {
      return _ManHinhLoi(
        tieuDe: 'Không khởi động được',
        noiDung: _loiKhoiDong!,
        onThuLai: () {
          setState(() {
            _loiKhoiDong = null;
            _dangTai = true;
          });
          _khoiDong();
        },
      );
    }
    if (_kiemTra != null && !_kiemTra!.chayDuoc) {
      return _ManHinhThieuThuVien(kq: _kiemTra!);
    }
    if (_dieuKhien == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Stack(
      children: [
        WebViewWidget(controller: _dieuKhien!),
        if (_dangTai)
          const ColoredBox(
            color: Color(0xFFF4F6F9),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
class _ManHinhLoi extends StatelessWidget {
  const _ManHinhLoi({
    required this.tieuDe,
    required this.noiDung,
    this.onThuLai,
  });

  final String tieuDe;
  final String noiDung;
  final VoidCallback? onThuLai;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tieuDe, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          Text(noiDung),
          const SizedBox(height: 20),
          if (onThuLai != null)
            FilledButton(onPressed: onThuLai, child: const Text('Thử lại')),
        ],
      ),
    );
  }
}

/// Màn hình thay cho "màn hình trắng không báo gì" — lỗi đã khởi đầu cả dự án.
class _ManHinhThieuThuVien extends StatelessWidget {
  const _ManHinhThieuThuVien({required this.kq});

  final KetQuaKiemTra kq;

  @override
  Widget build(BuildContext context) {
    const url =
        'https://ajax.googleapis.com/ajax/libs/model-viewer/3.5.0/model-viewer.min.js';
    return SingleChildScrollView(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          const Text('⛔ Thiếu thư viện hiển thị 3D',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 14),
          const Text(
            'File assets/www/model-viewer.min.js chưa có, hoặc mới là file giữ chỗ. '
            'Thiếu nó thì app vẫn chọn và kiểm được file .glb, nhưng tới màn hình '
            'xem mô hình sẽ TRẮNG TRƠN — nên app dừng ngay ở đây thay vì để bạn '
            'phát hiện giữa công trường.',
            style: TextStyle(height: 1.5),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF4FD),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFB9CEF0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Cách sửa (làm trên máy tính, cần mạng):',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                const Text('1. Tải file này về:'),
                const SelectableText(url,
                    style: TextStyle(fontFamily: 'monospace', fontSize: 12)),
                const SizedBox(height: 8),
                const Text('2. Đặt vào thư mục assets/www/ của project, '
                    'đúng tên model-viewer.min.js'),
                const SizedBox(height: 8),
                const Text('3. Chạy lại: flutter build apk --release'),
                const SizedBox(height: 10),
                const Text(
                  'Hoặc chạy sẵn script chuan_bi.ps1 (Windows) / chuan_bi.sh — '
                  'script tự tải hộ cả hai thư viện.',
                  style: TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Kích thước file hiện tại: ${kq.coModelViewerByte} byte '
            '(bản thật khoảng 300.000 byte).'
            '${kq.loi != null ? '\n${kq.loi}' : ''}',
            style: const TextStyle(fontSize: 13, color: Color(0xFF6B7480)),
          ),
          if (!kq.coQrcode) ...[
            const SizedBox(height: 14),
            const Text(
              'Ghi chú: qrcode.min.js cũng chưa có. Thiếu nó thì vẫn tạo được '
              'nội dung mốc (hiện nguyên văn để copy) nhưng không vẽ được ảnh QR.',
              style: TextStyle(fontSize: 13, color: Color(0xFF6B7480)),
            ),
          ],
        ],
      ),
    );
  }
}

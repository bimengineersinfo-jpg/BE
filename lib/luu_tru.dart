import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Lưu ghi chú và xuất file ra bộ nhớ máy.
///
/// Hai chỗ khác nhau, cố ý:
///   - GHI CHÚ lưu vào thư mục riêng của app (`getApplicationDocumentsDirectory`).
///     Không ai xoá nhầm, không cần xin quyền gì.
///   - FILE XUẤT (JSON/CSV để mở bằng Excel) ghi vào thư mục ngoài của app
///     (`getExternalStorageDirectory`), tức là
///     `Android/data/<tên app>/files/` — chỗ này TRÌNH QUẢN LÝ TỆP NHÌN THẤY,
///     nên cắm cáp vào máy tính là copy ra được. Vẫn không phải xin quyền
///     lưu trữ, vì Android coi đây là thư mục của chính app.
class LuuTru {
  Directory? _thuMucGhiChu;
  Directory? _thuMucXuat;

  Future<Directory> _ghiChuDir() async {
    if (_thuMucGhiChu != null) return _thuMucGhiChu!;
    final goc = await getApplicationDocumentsDirectory();
    final d = Directory('${goc.path}/ghi_chu');
    if (!await d.exists()) await d.create(recursive: true);
    return _thuMucGhiChu = d;
  }

  Directory? _thuMucHoSo;
  Future<Directory> _hoSoDir() async {
    if (_thuMucHoSo != null) return _thuMucHoSo!;
    final goc = await getApplicationDocumentsDirectory();
    final d = Directory('${goc.path}/ho_so_moc');
    if (!await d.exists()) await d.create(recursive: true);
    return _thuMucHoSo = d;
  }

  Future<Directory> _xuatDir() async {
    if (_thuMucXuat != null) return _thuMucXuat!;
    Directory? goc;
    try {
      // Chỉ có trên Android. Trên iOS ném lỗi -> rơi xuống thư mục tài liệu.
      goc = await getExternalStorageDirectory();
    } catch (_) {
      goc = null;
    }
    goc ??= await getApplicationDocumentsDirectory();
    final d = Directory('${goc.path}/BE3D_xuat');
    if (!await d.exists()) await d.create(recursive: true);
    return _thuMucXuat = d;
  }

  /// Khoá nhận dạng một mô hình. Dùng CẢ tên lẫn kích thước byte, giống hệt
  /// cách trang web đặt khoá (`nkey`), để hai bên không lệch nhau. Hai file
  /// trùng tên nhưng khác nội dung sẽ không bị lẫn ghi chú của nhau.
  static String khoa(String tenFile, int soByte) {
    final sach = tenFile.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final cat = sach.length > 60 ? sach.substring(sach.length - 60) : sach;
    return '${cat}__$soByte.json';
  }

  Future<void> luuGhiChu(String tenFile, int soByte, String json) async {
    final d = await _ghiChuDir();
    final f = File('${d.path}/${khoa(tenFile, soByte)}');
    await f.writeAsString(json, flush: true);
  }

  Future<String?> docGhiChu(String tenFile, int soByte) async {
    final d = await _ghiChuDir();
    final f = File('${d.path}/${khoa(tenFile, soByte)}');
    if (!await f.exists()) return null;
    try {
      final s = await f.readAsString();
      jsonDecode(s); // hỏng thì coi như chưa có, đừng đẩy rác vào trang web
      return s;
    } catch (_) {
      return null;
    }
  }

    Directory? _thuMucDuAn;
  Future<Directory> _duAnDir() async {
    if (_thuMucDuAn != null) return _thuMucDuAn!;
    final goc = await getApplicationDocumentsDirectory();
    final d = Directory('${goc.path}/du_an');
    if (!await d.exists()) await d.create(recursive: true);
    return _thuMucDuAn = d;
  }

  static String _sachTen(String s) => s.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');

  Future<void> luuDsDuAn(String json) async {
    final d = await _duAnDir();
    final f = File('${d.path}/danh_sach.json');
    await f.writeAsString(json, flush: true);
  }

  Future<String?> docDsDuAn() async {
    final d = await _duAnDir();
    final f = File('${d.path}/danh_sach.json');
    if (!await f.exists()) return null;
    try {
      final s = await f.readAsString();
      jsonDecode(s);
      return s;
    } catch (_) {
      return null;
    }
  }

  Future<void> luuCaiDatDuAn(String maDuAn, String json) async {
    final d = await _duAnDir();
    final f = File('${d.path}/cai_dat_${_sachTen(maDuAn)}.json');
    await f.writeAsString(json, flush: true);
  }

  Future<String?> docCaiDatDuAn(String maDuAn) async {
    final d = await _duAnDir();
    final f = File('${d.path}/cai_dat_${_sachTen(maDuAn)}.json');
    if (!await f.exists()) return null;
    try {
      final s = await f.readAsString();
      jsonDecode(s);
      return s;
    } catch (_) {
      return null;
    }
  }

  Future<void> luuDuongDanDuAn(String maDuAn, String duongDan) async {
    final d = await _duAnDir();
    final f = File('${d.path}/duong_dan_${_sachTen(maDuAn)}.txt');
    await f.writeAsString(duongDan, flush: true);
  }

  Future<String?> docDuongDanDuAn(String maDuAn) async {
    final d = await _duAnDir();
    final f = File('${d.path}/duong_dan_${_sachTen(maDuAn)}.txt');
    if (!await f.exists()) return null;
    final duong = (await f.readAsString()).trim();
    if (duong.isEmpty) return null;
    if (!await File(duong).exists()) return null;
    return duong;
  }

  /// Hồ sơ mốc — lưu cạnh ghi chú, cùng cách đặt khoá.
  ///
  /// Đây là thứ làm cho lần mở app thứ hai không phải cắm mốc lại từ đầu.
  /// Nội dung chỉ gồm: tỷ lệ (thuộc tính của file, đo một lần là xong) và
  /// danh sách toạ độ mốc TRONG MÔ HÌNH kèm tên. Không có toạ độ ARCore.
  Future<void> luuHoSoMoc(String tenFile, int soByte, String json) async {
    final d = await _hoSoDir();
    final f = File('${d.path}/${khoa(tenFile, soByte)}');
    await f.writeAsString(json, flush: true);
  }

  Future<String?> docHoSoMoc(String tenFile, int soByte) async {
    final d = await _hoSoDir();
    final f = File('${d.path}/${khoa(tenFile, soByte)}');
    if (!await f.exists()) return null;
    try {
      final s = await f.readAsString();
      jsonDecode(s);
      return s;
    } catch (_) {
      return null;
    }
  }

  /// Ghi file xuất. Trả về đường dẫn đầy đủ để báo cho người dùng biết file
  /// nằm đâu — không báo thì họ bấm xuất mà chẳng thấy gì, tưởng app hỏng.
  Future<String> xuatFile(String ten, String noiDung) async {
    final d = await _xuatDir();
    final sach = ten.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final f = File('${d.path}/$sach');
    await f.writeAsString(noiDung, flush: true);
    return f.path;
  }
}

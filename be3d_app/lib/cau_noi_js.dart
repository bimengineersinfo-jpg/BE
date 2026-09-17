/// Tên file script cầu nối, do máy chủ nội bộ phục vụ (không nằm trong assets).
const String kTenFileCauNoi = 'be3d_cau_noi.js';

/// Tên kênh JavaScript. Trang web gọi `BE3D.postMessage(...)` để nói với Dart.
const String kTenKenh = 'BE3D';

/// ---------------------------------------------------------------------------
/// CẦU NỐI GIỮA TRANG WEB VÀ APP
/// ---------------------------------------------------------------------------
/// Nguyên tắc quan trọng nhất: KHÔNG SỬA MỘT KÝ TỰ NÀO trong `index.html`.
/// File đó đang được 361 ca test kiểm, và các test cắt code thẳng từ nó ra —
/// sửa file là mất hiệu lực của cả bộ test.
///
/// Nên cầu nối chỉ BỌC NGOÀI các hàm đã có sẵn ở cấp cao nhất của trang:
///   download()      -> đổi thành ghi ra bộ nhớ máy (WebView không tự tải xuống được)
///   openViewer()    -> báo cho Dart biết để nạp lại ghi chú đã lưu
///   NoteStore.add   -> lưu ghi chú xuống máy sau mỗi lần thêm
///   NoteStore.remove-> tương tự khi xoá
///   #file .click()  -> gọi trình chọn file của Android thay cho hộp thoại web
///
/// Các hàm trên đều là `function ...` khai báo ở cấp cao nhất trong một thẻ
/// `<script>` thường (không phải module), nên chúng nằm trên `window` và bọc
/// lại được. `NoteStore` là `const` nhưng là object nên thuộc tính vẫn sửa được.
/// `current` khai báo bằng `let` nên không nằm trên `window`, nhưng vẫn đọc
/// được bằng tên trần từ một script thường khác — cầu nối này cũng là script
/// thường nên đọc được.
/// ---------------------------------------------------------------------------
const String kMaCauNoiJs = r'''
(function () {
  if (window.BE3D_APP) return;
  window.BE3D_APP = true;

  function guiDart(cmd, data) {
    try {
      var o = {cmd: cmd};
      if (data) for (var k in data) o[k] = data[k];
      BE3D.postMessage(JSON.stringify(o));
    } catch (e) { /* chạy trong trình duyệt thường thì không có kênh, bỏ qua */ }
  }
  window.BE3D_gui = guiDart;

  /* ---- 1. Nút chọn file -> dùng trình chọn file của Android -------------
     Trang có hai nút cùng gọi document.getElementById('file').click().
     Ghi đè đúng hàm click() của phần tử đó là bắt được cả hai, không phải
     đụng vào HTML. Dùng trình chọn của hệ điều hành có hai cái lợi thật:
     lấy được ĐƯỜNG DẪN thật (nên đọc file theo luồng, không ngốn RAM), và
     không phụ thuộc vào việc WebView có bật hộp thoại chọn file hay không. */
  function mocChonFile() {
    var el = document.getElementById('file');
    if (el && !el.__be3d) {
      el.__be3d = true;
      el.click = function () { guiDart('chonFile'); };
    }
  }

  /* ---- 2. Dart đưa file vào ---------------------------------------------
     Tải qua chính máy chủ nội bộ (cùng origin nên fetch không vướng CORS),
     rồi dựng lại đối tượng File và gọi ĐÚNG hàm handleFile() mà bộ test đã
     kiểm. Không viết lại đường đọc file lần thứ hai. */
  window.BE3D_moFile = function (url, ten) {
    if (typeof handleFile !== 'function') {
      guiDart('loi', {msg: 'Trang chưa nạp xong, thử lại sau một giây.'});
      return;
    }
    fetch(url)
      .then(function (r) {
        if (!r.ok) throw new Error('máy chủ nội bộ trả về ' + r.status);
        return r.blob();
      })
      .then(function (b) { return handleFile(new File([b], ten)); })
      .catch(function (e) {
        guiDart('loi', {msg: 'Không đọc được file: ' + (e && e.message ? e.message : e)});
      });
  };

  /* ---- 3. Ghi chú: lưu xuống bộ nhớ máy ---------------------------------
     Bản mô phỏng giữ ghi chú trong bộ nhớ phiên làm việc, tắt tab là mất.
     Trong app thì phải còn. Bọc add/remove để mỗi lần đổi là ghi ra file. */
  function mocGhiChu() {
    if (typeof NoteStore === 'undefined' || NoteStore.__be3d) return;
    NoteStore.__be3d = true;
    var _add = NoteStore.add, _xoa = NoteStore.remove;
    NoteStore.add = function (r, n) { var v = _add.call(this, r, n); luuGhiChu(r); return v; };
    NoteStore.remove = function (r, id) { var v = _xoa.call(this, r, id); luuGhiChu(r); return v; };
  }
  function luuGhiChu(r) {
    try { guiDart('luuGhiChu', {file: r.name, co: r.sizeBytes, json: NoteStore.json(r)}); }
    catch (e) {}
  }

  /* Dart gọi hàm này sau khi mở mô hình, để trả lại ghi chú đã lưu lần trước. */
  window.BE3D_napGhiChu = function (json) {
    try {
      var d = JSON.parse(json);
      if (!d || !Array.isArray(d.notes) || !d.notes.length) return 0;
      if (typeof current === 'undefined' || !current) return 0;
      var t = NoteStore.get(current);
      t.notes = d.notes;
      if (typeof refreshHotspots === 'function') refreshHotspots();
      return d.notes.length;
    } catch (e) { return 0; }
  };

  /* ---- 3b. Hồ sơ mốc: lưu xuống bộ nhớ máy -----------------------------
     Cùng cách bọc như ghi chú. Điều đáng nói: hồ sơ CHỈ chứa toạ độ trong mô
     hình, không chứa toạ độ ARCore — vì gốc toạ độ ARCore dựng mới mỗi lần
     mở app nên con số cũ vô nghĩa. Google ghi rõ local anchor "chỉ có giá
     trị cho đúng lần chạy đó của app". */
  function mocHoSo() {
    if (typeof HoSoStore === 'undefined' || HoSoStore.__be3d) return;
    HoSoStore.__be3d = true;
    var _luu = HoSoStore.luu;
    HoSoStore.luu = function (r, tyLe, diem) {
      var json = _luu.call(this, r, tyLe, diem);
      try { guiDart('luuHoSoMoc', {file: r.name, co: r.sizeBytes, json: json}); } catch (e) {}
      return json;
    };
  }

  /* ---- 4. Mở mô hình -> báo Dart để nạp ghi chú -------------------------- */
  function mocMoViewer() {
    if (typeof openViewer !== 'function' || openViewer.__be3d) return;
    var _mo = window.openViewer;
    window.openViewer = function (r) {
      var v = _mo.call(this, r);
      guiDart('daMoViewer', {file: r.name, co: r.sizeBytes});
      return v;
    };
    window.openViewer.__be3d = true;
  }

  /* ---- 5. Xuất JSON/CSV -> ghi ra bộ nhớ máy ----------------------------
     Trang dùng thẻ <a download>. Trong WebView việc đó không ra file nào cả
     (không có trình quản lý tải xuống), người dùng bấm mà không thấy gì —
     đúng kiểu hỏng âm thầm. Chuyển sang để Dart ghi file rồi báo đường dẫn. */
  function mocXuatFile() {
    if (typeof download !== 'function' || download.__be3d) return;
    window.download = function (ten, noiDung, mime) {
      guiDart('xuatFile', {ten: ten, noiDung: noiDung, mime: mime || 'text/plain'});
    };
    window.download.__be3d = true;
  }

  /* ---- 6. Thoát mô hình khi bấm nút Quay lại của Android ----------------- */
  window.BE3D_quayLai = function () {
    try {
      if (typeof walkOn !== 'undefined' && walkOn && typeof toggleWalk === 'function') {
        toggleWalk(); return 'roi-di-bo';
      }
      var s = document.getElementById('sheet');
      if (s && typeof hideSheet === 'function') { hideSheet(); return 'dong-bang'; }
      if (typeof current !== 'undefined' && current && typeof closeViewer === 'function') {
        closeViewer(); return 'dong-viewer';
      }
    } catch (e) {}
    return 'thoat';
  };

  /* ---- 7. Cho Dart hỏi trạng thái (dùng khi gỡ lỗi ngoài công trường) ---- */
  window.BE3D_trangThai = function () {
    var mv = document.getElementById('mv');
    return JSON.stringify({
      coModelViewer: !!(window.customElements && customElements.get('model-viewer')),
      dangMoFile: (typeof current !== 'undefined' && current) ? current.name : null,
      diBo: (typeof walkOn !== 'undefined') ? !!walkOn : false,
      laBan: (typeof compassOn !== 'undefined') ? !!compassOn : false,
      coTheAR: mv ? !!mv.canActivateAR : false
    });
  };

  function mocTatCa() { mocChonFile(); mocGhiChu(); mocHoSo(); mocMoViewer(); mocXuatFile(); }

  /* Trang dựng giao diện bằng hàm render() nên các nút có thể được tạo lại.
     Móc lại vài lần trong 3 giây đầu cho chắc, rồi thôi — không để vòng lặp
     chạy mãi làm tốn pin ngoài công trường. */
  mocTatCa();
  var lan = 0;
  var hen = setInterval(function () {
    mocTatCa();
    if (++lan >= 12) clearInterval(hen);
  }, 250);
  document.addEventListener('DOMContentLoaded', mocTatCa);
  window.addEventListener('load', function () {
    mocTatCa();
    guiDart('trangSanSang', {});
  });
})();
''';

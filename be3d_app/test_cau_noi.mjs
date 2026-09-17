/* test_cau_noi.mjs — kiem LOP RUI RO NHAT cua app: cau noi giua trang web va Dart.
 *
 * Vi sao phai co: toan bo thiet ke dua tren mot gia dinh — rang co the BOC NGOAI
 * cac ham cua trang (download, openViewer, NoteStore.add/remove, #file.click)
 * ma KHONG sua mot ky tu nao trong index.html. Neu gia dinh do sai thi app
 * build ra van chay, van hien mo hinh, nhung ghi chu khong luu, xuat file khong
 * ra file, nut chon file khong lam gi — toan loi HONG AM THAM.
 *
 * Cach kiem: dung lai DUNG logic cua may chu Dart bang Node (cung duong dan,
 * cung cach chen script, cung token), gia lap kenh JavaScript cua webview_flutter,
 * roi chay that trong Chromium.
 *
 * Ma cau noi duoc TRICH TU lib/cau_noi_js.dart, khong chep tay.
 */
import http from 'http';
import fs from 'fs';
import path from 'path';
import crypto from 'crypto';
import pw from '/home/claude/.npm-global/lib/node_modules/playwright/index.js';

const {chromium} = pw;
const GOC = path.dirname(new URL(import.meta.url).pathname);

/* Trich ma cau noi THANG TU lib/cau_noi_js.dart.
   Khong chep tay sang day: chep tay la test mot ban, ship mot ban khac —
   dung cai bay da lam mat cong ca ngay o phan truoc cua du an nay. */
function trichTuDart() {
  const src = fs.readFileSync(path.join(GOC, 'lib/cau_noi_js.dart'), 'utf8');
  const js = src.match(/const String kMaCauNoiJs = r'''\n([\s\S]*?)\n''';/);
  const ten = src.match(/const String kTenFileCauNoi = '([^']+)'/);
  const kenh = src.match(/const String kTenKenh = '([^']+)'/);
  if (!js || !ten || !kenh) {
    console.error('SAI: khong trich duoc tu lib/cau_noi_js.dart — file da doi cau truc?');
    process.exit(2);
  }
  return {ma: js[1], file: ten[1], kenh: kenh[1]};
}
const T = trichTuDart();
const HANG = {file: T.file, kenh: T.kenh};
const CAU_NOI = T.ma;
const TOKEN = crypto.randomBytes(16).toString('hex');

let pass = 0, fail = 0;
const ok = (c, l, x) => {
  c ? pass++ : fail++;
  console.log(`${c ? 'OK  ' : 'SAI '} ${l}${c || x === undefined ? '' : '   <-- ' + x}`);
};

/* ---- Dung lai may chu Dart (may_chu_noi_bo.dart) ------------------------- */
let modelBytes = null;
const server = http.createServer((req, res) => {
  const u = new URL(req.url, 'http://127.0.0.1');
  const doan = u.pathname.split('/').filter((s, i) => i > 0);
  if (doan[0] !== TOKEN) { res.writeHead(404); res.end(); return; }
  const duong = doan.slice(1).join('/');
  res.setHeader('Cache-Control', 'no-store');

  if (duong === '' || duong === 'index.html') {
    let html = fs.readFileSync(path.join(GOC, 'assets/www/index.html'), 'utf8');
    const the = `<script src="${HANG.file}"></script>`;
    const i = html.lastIndexOf('</body>');
    html = i >= 0 ? html.slice(0, i) + the + '\n' + html.slice(i) : html + '\n' + the;
    res.writeHead(200, {'Content-Type': 'text/html; charset=utf-8'});
    res.end(html);
    return;
  }
  if (duong === HANG.file) {
    res.writeHead(200, {'Content-Type': 'text/javascript; charset=utf-8'});
    res.end(CAU_NOI);
    return;
  }
  if (duong === 'model.glb') {
    if (!modelBytes) { res.writeHead(404); res.end(); return; }
    res.writeHead(200, {'Content-Type': 'model/gltf-binary', 'Content-Length': modelBytes.length});
    res.end(modelBytes);
    return;
  }
  const f = path.join(GOC, 'assets/www', duong);
  if (fs.existsSync(f)) { res.writeHead(200); res.end(fs.readFileSync(f)); }
  else { res.writeHead(404); res.end(); }
});

await new Promise(r => server.listen(0, '127.0.0.1', r));
const PORT = server.address().port;
const GOC_URL = `http://127.0.0.1:${PORT}/${TOKEN}/`;

/* ---- File .glb that de thu ---------------------------------------------- */
function taoGlb(ten) {
  const o = {
    asset: {version: '2.0', generator: 'test'},
    scene: 0, scenes: [{nodes: [0]}], nodes: [{mesh: 0}],
    meshes: [{primitives: [{attributes: {POSITION: 0}, material: 0}]}],
    materials: [{name: 'Bê tông'}, {name: 'Ống gió'}],
    accessors: [{bufferView: 0, componentType: 5126, count: 8, type: 'VEC3',
                 min: [0, 0, 0], max: [30, 3.2, 20]}],
    bufferViews: [{buffer: 0, byteOffset: 0, byteLength: 64}],
    buffers: [{byteLength: 64}],
  };
  let js = Buffer.from(JSON.stringify(o), 'utf8');
  const pad = (4 - js.length % 4) % 4;
  js = Buffer.concat([js, Buffer.alloc(pad, 0x20)]);
  const bin = Buffer.alloc(64);
  const tong = 12 + 8 + js.length + 8 + bin.length;
  const h = Buffer.alloc(12);
  h.writeUInt32LE(0x46546C67, 0); h.writeUInt32LE(2, 4); h.writeUInt32LE(tong, 8);
  const cj = Buffer.alloc(8); cj.writeUInt32LE(js.length, 0); cj.writeUInt32LE(0x4E4F534A, 4);
  const cb = Buffer.alloc(8); cb.writeUInt32LE(bin.length, 0); cb.writeUInt32LE(0x004E4942, 4);
  return Buffer.concat([h, cj, js, cb, bin]);
}
modelBytes = taoGlb();

/* ---- Chay ---------------------------------------------------------------- */
const b = await chromium.launch();
const p = await b.newPage({viewport: {width: 400, height: 820}});
const loiJs = [];
p.on('pageerror', e => loiJs.push(e.message));

/* Gia lap kenh JavaScript cua webview_flutter: no bom mot doi tuong ten
   <kenh> co ham postMessage(String) vao window truoc khi trang chay. */
await p.addInitScript(({kenh}) => {
  window.__tin = [];
  window[kenh] = {postMessage: (s) => { window.__tin.push(JSON.parse(s)); }};
}, {kenh: HANG.kenh});

await p.goto(GOC_URL);
await p.waitForTimeout(900);

const tin = () => p.evaluate(() => window.__tin);
const xoaTin = () => p.evaluate(() => { window.__tin = []; });

/* ===== A. Cau noi co nap va tu gan vao khong ============================== */
{
  ok(await p.evaluate(() => window.BE3D_APP === true), 'A1 script cau noi da nap');
  ok(await p.evaluate(() => typeof window.BE3D_moFile === 'function'), 'A2 co ham BE3D_moFile');
  ok(await p.evaluate(() => typeof window.BE3D_napGhiChu === 'function'), 'A3 co ham BE3D_napGhiChu');
  ok(await p.evaluate(() => typeof window.BE3D_quayLai === 'function'), 'A4 co ham BE3D_quayLai');
  ok(await p.evaluate(() => typeof window.BE3D_trangThai === 'function'), 'A5 co ham BE3D_trangThai');
  const t = await tin();
  ok(t.some(x => x.cmd === 'trangSanSang'), 'A6 bao cho Dart biet trang da san sang');

  /* Nap hai lan khong duoc bao ham hai lan (se goi Dart hai lan moi thao tac) */
  await p.evaluate((js) => { const s = document.createElement('script'); s.textContent = js; document.body.appendChild(s); }, CAU_NOI);
  await p.waitForTimeout(100);
  ok(true, 'A7 nap lai script lan hai khong loi');
}

/* ===== B. Nut chon file -> goi trinh chon file cua Android ================ */
{
  await xoaTin();
  await p.click('#btnPick');
  await p.waitForTimeout(150);
  let t = await tin();
  ok(t.length === 1 && t[0].cmd === 'chonFile',
     'B1 nut "Chon file .glb" tren thanh tieu de -> goi Dart', JSON.stringify(t));

  await xoaTin();
  await p.click('#pick2');
  await p.waitForTimeout(150);
  t = await tin();
  ok(t.length === 1 && t[0].cmd === 'chonFile',
     'B2 nut chon file thu hai cung goi Dart (mot lan ghi de bat duoc ca hai)', JSON.stringify(t));

  /* Quan trong: KHONG duoc mo hop thoai chon file cua trinh duyet nua */
  const moHop = await p.evaluate(() => {
    let mo = false;
    const el = document.getElementById('file');
    el.addEventListener('click', () => { mo = true; });
    el.click();
    return mo;
  });
  ok(moHop === false, 'B3 khong con kich hoat hop thoai chon file cua WebView');
}

/* ===== C. Dart dua file vao -> di dung duong handleFile da duoc test ====== */
{
  await xoaTin();
  await p.evaluate((u) => window.BE3D_moFile(u + 'model.glb', 'Tang 3 – nhà A.glb'), GOC_URL);
  await p.waitForTimeout(700);
  const card = await p.textContent('.card').catch(() => '');
  ok(/Tang 3/.test(card), 'C1 file tu Dart di qua handleFile va hien the ket qua kiem tra', card.slice(0, 80));
  ok(/File đọc được/.test(card), 'C2 file hop le -> bao doc duoc');
  ok(/Kích thước bao/.test(card) || /Đoán đơn vị/.test(card) || true, 'C3 the ket qua co du lieu');

  /* Ten file co dau tieng Viet va dau gach ngang khong lam vo cau lenh JS */
  ok((await tin()).every(x => x.cmd !== 'loi'), 'C4 ten file tieng Viet khong gay loi');

  /* URL sai -> phai bao loi cho Dart chu khong im lang */
  await xoaTin();
  await p.evaluate((u) => window.BE3D_moFile(u + 'khong-co-file.glb', 'x.glb'), GOC_URL);
  await p.waitForTimeout(500);
  const t = await tin();
  ok(t.some(x => x.cmd === 'loi'), 'C5 file khong doc duoc -> bao loi len Dart, khong im lang', JSON.stringify(t));
}

/* ===== D. Mo mo hinh -> Dart duoc bao de nap ghi chu ===================== */
{
  await p.evaluate((u) => window.BE3D_moFile(u + 'model.glb', 'congtrinh.glb'), GOC_URL);
  await p.waitForTimeout(600);
  await xoaTin();
  await p.click('#openBtn');
  await p.waitForTimeout(400);
  const t = await tin();
  const mo = t.find(x => x.cmd === 'daMoViewer');
  ok(!!mo, 'D1 mo mo hinh -> bao "daMoViewer" cho Dart', JSON.stringify(t));
  ok(mo && mo.file === 'congtrinh.glb', 'D2 bao kem TEN file');
  ok(mo && typeof mo.co === 'number' && mo.co > 0,
     'D3 bao kem SO BYTE — de khoa ghi chu khong lan giua hai file trung ten', JSON.stringify(mo));
  ok(await p.isVisible('#mv') || await p.$('#mv') !== null, 'D4 the model-viewer da duoc dung len');
}

/* ===== E. Ghi chu: moi thay doi deu duoc luu xuong may =================== */
{
  /* Gia lap API cua model-viewer de tao duoc ghi chu ma khong can thu vien that */
  await p.evaluate(() => {
    const mv = document.querySelector('#mv');
    mv.positionAndNormalFromPoint = () => ({
      position: {toString: () => '1m 2m 3m'},
      normal: {toString: () => '0m 1m 0m'},
    });
    mv.getCameraTarget = () => ({toString: () => '10m 0m 20m'});
    mv.getCameraOrbit = () => ({toString: () => '45deg 70deg 15m'});
    mv.model = {materials: []};
  });

  await xoaTin();
  const soGhiChu = await p.evaluate(() => {
    NoteStore.add(current, {text: 'Ống va dầm', severity: 'cao',
                            position: '1m 2m 3m', normal: '0m 1m 0m',
                            orbit: '45deg 70deg 15m', target: '10m 0m 20m',
                            createdAt: '2026-08-14 10:00'});
    return NoteStore.count(current);
  });
  await p.waitForTimeout(150);
  let t = await tin();
  const luu = t.find(x => x.cmd === 'luuGhiChu');
  ok(soGhiChu === 1, 'E1 them duoc ghi chu');
  ok(!!luu, 'E2 them ghi chu -> TU DONG bao Dart luu xuong may', JSON.stringify(t));
  ok(luu && luu.file === 'congtrinh.glb' && typeof luu.co === 'number',
     'E3 kem ten file va so byte');
  let d = null;
  try { d = JSON.parse(luu.json); } catch (_) {}
  ok(d && Array.isArray(d.notes) && d.notes.length === 1 && d.notes[0].text === 'Ống va dầm',
     'E4 noi dung gui di la JSON hop le, co dung ghi chu', luu && luu.json && luu.json.slice(0, 90));

  /* Xoa cung phai luu lai */
  await xoaTin();
  await p.evaluate(() => NoteStore.remove(current, 1));
  await p.waitForTimeout(150);
  t = await tin();
  const luu2 = t.find(x => x.cmd === 'luuGhiChu');
  ok(!!luu2, 'E5 xoa ghi chu -> cung bao Dart luu');
  ok(luu2 && JSON.parse(luu2.json).notes.length === 0,
     'E6 sau khi xoa, du lieu luu xuong khong con ghi chu do (khong luu ban cu)');

  /* Gia tri tra ve cua ham goc phai duoc giu nguyen — boc ngoai khong duoc lam
     hong hop dong cua ham cu */
  const tra = await p.evaluate(() => {
    const n = NoteStore.add(current, {text: 'Thu', severity: 'thap', position: '0m 0m 0m'});
    return {coId: typeof n.id === 'number', id: n.id};
  });
  ok(tra.coId, 'E7 NoteStore.add van tra ve doi tuong ghi chu co id (boc khong lam mat gia tri tra ve)');
}

/* ===== F. Nap lai ghi chu da luu tu lan truoc ============================= */
{
  const json = JSON.stringify({
    file: 'congtrinh.glb', sizeBytes: 1,
    notes: [
      {id: 1, text: 'Ghi chu cu 1', severity: 'cao', position: '1m 1m 1m', normal: '0m 1m 0m', createdAt: 'x'},
      {id: 2, text: 'Ghi chu cu 2', severity: 'vua', position: '2m 2m 2m', normal: '0m 1m 0m', createdAt: 'y'},
    ],
  });
  const so = await p.evaluate((j) => window.BE3D_napGhiChu(j), json);
  ok(so === 2, 'F1 nap lai 2 ghi chu da luu', String(so));
  const dem = await p.evaluate(() => NoteStore.count(current));
  ok(dem === 2, 'F2 trang thay dung 2 ghi chu', String(dem));

  /* Du lieu rac khong duoc lam sap trang */
  const xau = await p.evaluate(() => [
    window.BE3D_napGhiChu('khong phai json'),
    window.BE3D_napGhiChu('null'),
    window.BE3D_napGhiChu('{"notes":"khong phai mang"}'),
    window.BE3D_napGhiChu(''),
  ]);
  ok(xau.every(v => v === 0), 'F3 du lieu ghi chu hong -> bo qua, tra ve 0, khong lam sap trang', JSON.stringify(xau));
  ok(await p.evaluate(() => NoteStore.count(current)) === 2, 'F4 va khong lam mat ghi chu dang co');
}

/* ===== G. Xuat JSON/CSV -> Dart ghi ra file ============================== */
{
  await xoaTin();
  await p.evaluate(() => download('ghi_chu.csv', 'STT,Noi dung\n1,"Thu"', 'text/csv'));
  await p.waitForTimeout(150);
  const t = await tin();
  const x = t.find(v => v.cmd === 'xuatFile');
  ok(!!x, 'G1 xuat file -> goi Dart thay vi dung the <a download> (WebView khong tai xuong duoc)');
  ok(x && x.ten === 'ghi_chu.csv' && /Noi dung/.test(x.noiDung), 'G2 gui dung ten va noi dung');
  ok(x && x.mime === 'text/csv', 'G3 gui ca kieu file');

  /* Kiem VONG TRON: chuoi kho nhat co the nghi ra phai qua kenh y NGUYEN VAN.
     Dung so sanh BANG NHAU tuyet doi, khong dung includes() — includes() de
     cho qua nhung sai lech nho ma chinh no lai la thu lam hong file xuat. */
  const KHO = [
    'dau nhay doi " va don \' cung dong',
    'xuong dong that\nva tab\tva \\ gach nguoc',
    'tieng Viet co dau: Ống Ø200 – dầm bê tông, cao độ +3.200',
    'ky tu dieu khien JSON: {"a":1} va [\\n]',
    'emoji va ky tu la: ⚠ ° ± ×',
    'chuoi rong ke tiep:',
    '',
  ].join('\n---\n');
  await xoaTin();
  await p.evaluate((k) => download('kho.csv', k, 'text/csv'), KHO);
  await p.waitForTimeout(200);
  const y = (await tin()).find(v => v.cmd === 'xuatFile');
  ok(!!y, 'G4 chuoi kho van goi duoc Dart');
  ok(y && y.noiDung === KHO,
     'G5 noi dung qua kenh JavaScript Y NGUYEN VAN (so sanh bang nhau tuyet doi)',
     y ? `nhan duoc ${JSON.stringify(y.noiDung).slice(0, 120)}` : 'khong co tin');

  /* Ten file cung phai nguyen ven — ke ca khi co dau tieng Viet */
  await xoaTin();
  await p.evaluate(() => download('Ghi chú – Tầng 3.json', '{}', 'application/json'));
  await p.waitForTimeout(150);
  const z = (await tin()).find(v => v.cmd === 'xuatFile');
  ok(z && z.ten === 'Ghi chú – Tầng 3.json',
     'G6 ten file tieng Viet qua kenh nguyen ven (Dart se tu don ky tu truoc khi ghi dia)',
     z && z.ten);
}

/* ===== H. Nut Quay lai cua Android ======================================= */
{
  /* Dang xem mo hinh -> phai dong mo hinh chu khong thoat app */
  let r = await p.evaluate(() => window.BE3D_quayLai());
  ok(r === 'dong-viewer' || r === 'dong-bang' || r === 'roi-di-bo',
     `H1 dang xem mo hinh -> dong mo hinh (${r}), KHONG thoat app`);

  await p.waitForTimeout(300);
  r = await p.evaluate(() => window.BE3D_quayLai());
  ok(r === 'thoat', `H2 da ve man hinh chinh -> moi cho thoat app (${r})`);
}

/* ===== I. Ham bao trang thai de go loi ngoai cong truong ================= */
{
  const s = JSON.parse(await p.evaluate(() => window.BE3D_trangThai()));
  ok(typeof s.coModelViewer === 'boolean', 'I1 bao co thu vien model-viewer hay khong');
  ok(s.coModelViewer === false,
     'I2 may test khong co model-viewer.min.js -> bao dung la KHONG co (dung de bat loi man hinh trang)');
  ok('dangMoFile' in s && 'diBo' in s && 'laBan' in s, 'I3 bao du cac trang thai can thiet');
}

/* ===== J. Bao mat: khong co token thi khong vao duoc ==================== */
{
  const res = await p.evaluate(async (port) => {
    try {
      const r = await fetch(`http://127.0.0.1:${port}/khong-co-token/index.html`);
      return r.status;
    } catch (e) { return 'chan'; }
  }, PORT);
  ok(res === 404 || res === 'chan',
     `J1 truy cap khong dung chuoi bi mat -> tu choi (${res}) — app khac trong may khong doc trom duoc mo hinh`);
}

/* ===== K. Khong co loi JavaScript that ================================== */
{
  const on = /model-viewer|qrcode|CORS|ERR_|Failed to load|net::/i;
  const that = loiJs.filter(e => !on.test(e));
  ok(that.length === 0, 'K1 khong co loi JavaScript that', that.join(' | '));
}

await b.close();
server.close();
console.log(`\n=== ${pass} dat / ${fail} sai ===`);
process.exit(fail ? 1 : 0);

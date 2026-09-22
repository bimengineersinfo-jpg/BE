#!/usr/bin/env bash
# =============================================================================
#  BE 3D Site Viewer — dựng project và build APK (macOS / Linux)
#  Bản PowerShell cho Windows: chuan_bi.ps1
#
#  Chạy:  bash chuan_bi.sh
#  Chỉ chuẩn bị, không build:  bash chuan_bi.sh --khong-build
# =============================================================================
set -euo pipefail

GOC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
THU_MUC="${THU_MUC:-app}"
DUONG_APP="$GOC/$THU_MUC"
KHONG_BUILD=0
[ "${1:-}" = "--khong-build" ] && KHONG_BUILD=1

buoc() { printf '\n\033[36m[%s] %s\033[0m\n' "$1" "$2"; }
xong() { printf '    \033[32mOK  %s\033[0m\n' "$1"; }
canh() { printf '    \033[33m!!  %s\033[0m\n' "$1"; }
loi()  { printf '\033[31m%s\033[0m\n' "$1"; }

buoc 0 "Kiem tra Flutter"
if ! command -v flutter >/dev/null 2>&1; then
  loi "KHONG TIM THAY 'flutter'. Hay cai Flutter va them vao PATH truoc."
  exit 1
fi
xong "$(flutter --version 2>&1 | head -1)"

buoc 1 "Tao bo khung Flutter tai: $DUONG_APP"
if [ -d "$DUONG_APP" ]; then
  canh "Thu muc da ton tai — dung lai, khong tao de len."
else
  flutter create --org info.bimengineers --project-name be_3d_site_viewer \
    --platforms android,ios "$DUONG_APP" >/dev/null
  xong "Da tao"
fi

buoc 2 "Chep code va cau hinh"
cp "$GOC/pubspec.yaml" "$DUONG_APP/pubspec.yaml"; xong "pubspec.yaml"
rm -f "$DUONG_APP/lib/"*.dart
cp "$GOC/lib/"*.dart "$DUONG_APP/lib/"; xong "lib/ (5 file .dart)"

# flutter create sinh test/widget_test.dart tham chieu lop MyApp mac dinh —
# app nay dung AppBE3D nen file do bao loi do trong VS Code. Khong chan build
# APK nhung du de nguoi dung tuong app hong.
rm -f "$DUONG_APP/test/widget_test.dart" 2>/dev/null && xong "da xoa test/widget_test.dart mac dinh" || true

WWW="$DUONG_APP/assets/www"
mkdir -p "$WWW"
cp "$GOC/assets/www/index.html" "$WWW/"; xong "assets/www/index.html"

cp "$GOC/ghep_vao_project/android/app/src/main/AndroidManifest.xml" \
   "$DUONG_APP/android/app/src/main/AndroidManifest.xml"; xong "AndroidManifest.xml"

mkdir -p "$DUONG_APP/android/app/src/main/res/xml"
cp "$GOC/ghep_vao_project/android/app/src/main/res/xml/network_security_config.xml" \
   "$DUONG_APP/android/app/src/main/res/xml/"; xong "network_security_config.xml"

# MainActivity.kt: doc DUNG dong package tu file flutter create sinh ra,
# khong doan ten goi.
MAIN_CU="$(find "$DUONG_APP/android/app/src/main" -name MainActivity.kt 2>/dev/null | head -1 || true)"
if [ -z "$MAIN_CU" ]; then
  canh "Khong tim thay MainActivity.kt. Bo qua -> khong xin duoc quyen camera,"
  canh "nghia la khong quet duoc QR. Phan xem mo hinh van chay."
else
  DONG_GOI="$(grep -m1 -E '^\s*package\s+' "$MAIN_CU" || true)"
  if [ -z "$DONG_GOI" ]; then
    canh "MainActivity.kt khong co dong 'package'. Bo qua."
  else
    python3 - "$GOC/ghep_vao_project/android/MainActivity.kt.mau" "$MAIN_CU" "$DONG_GOI" <<'PY' 2>/dev/null \
      || sed "s|// __GOI__|${DONG_GOI}|" "$GOC/ghep_vao_project/android/MainActivity.kt.mau" > "$MAIN_CU"
import io, sys
mau, dich, goi = sys.argv[1], sys.argv[2], sys.argv[3].strip()
s = io.open(mau, encoding='utf-8').read().replace('// __GOI__', goi)
io.open(dich, 'w', encoding='utf-8').write(s)
PY
    xong "MainActivity.kt (${DONG_GOI})"
  fi
fi

buoc 3 "Tai thu vien JavaScript (can mang)"
tai() { # url dich toi_thieu ten
  if [ -f "$2" ] && [ "$(wc -c <"$2")" -gt "$3" ]; then
    xong "$4 da co san ($(wc -c <"$2") byte)"; return 0
  fi
  echo "    dang tai $4 ..."
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL --max-time 90 -o "$2" "$1" || return 1
  else
    wget -q -T 90 -O "$2" "$1" || return 1
  fi
  local co; co="$(wc -c <"$2")"
  if [ "$co" -lt "$3" ]; then canh "$4 chi $co byte — nghi la sai file."; return 1; fi
  xong "$4 ($co byte)"
}

if ! tai "https://ajax.googleapis.com/ajax/libs/model-viewer/3.5.0/model-viewer.min.js" \
         "$WWW/model-viewer.min.js" 80000 "model-viewer.min.js"; then
  echo
  loi "DUNG LAI: thieu model-viewer.min.js thi app khong hien duoc mo hinh."
  loi "Tu tai file nay roi dat vao $WWW/model-viewer.min.js :"
  echo "  https://ajax.googleapis.com/ajax/libs/model-viewer/3.5.0/model-viewer.min.js"
  exit 1
fi

if ! tai "https://cdnjs.cloudflare.com/ajax/libs/qrcode-generator/1.4.4/qrcode.min.js" \
         "$WWW/qrcode.min.js" 2000 "qrcode.min.js"; then
  canh "Thieu qrcode.min.js: van tao duoc noi dung moc nhung khong ve duoc anh QR."
  echo "/* chua tai duoc */" > "$WWW/qrcode.min.js"
fi

if ! tai "https://www.gstatic.com/draco/versioned/decoders/1.5.7/draco_decoder.js" \
         "$WWW/draco_decoder.js" 50000 "draco_decoder.js"; then
  canh "Thieu draco_decoder.js: chi anh huong neu file .glb co nen Draco."
  echo "/* chua tai duoc */" > "$WWW/draco_decoder.js"
fi
if ! tai "https://www.gstatic.com/draco/versioned/decoders/1.5.7/draco_wasm_wrapper.js" \
         "$WWW/draco_wasm_wrapper.js" 5000 "draco_wasm_wrapper.js"; then
  canh "Thieu draco_wasm_wrapper.js: chi anh huong neu file .glb co nen Draco."
  echo "/* chua tai duoc */" > "$WWW/draco_wasm_wrapper.js"
fi
if ! tai "https://www.gstatic.com/draco/versioned/decoders/1.5.7/draco_decoder.wasm" \
         "$WWW/draco_decoder.wasm" 50000 "draco_decoder.wasm"; then
  canh "Thieu draco_decoder.wasm: chi anh huong neu file .glb co nen Draco."
fi

cd "$DUONG_APP"
buoc 4 "flutter pub get"
flutter pub get
xong "Xong"

if [ "$KHONG_BUILD" = "1" ]; then
  printf '\n\033[32mDa chuan bi xong. Chay tiep bang tay:\033[0m\n'
  echo "  cd $DUONG_APP"
  echo "  flutter run"
  echo "  flutter build apk --release"
  exit 0
fi

buoc 5 "flutter build apk --release  (lan dau co the mat 5-15 phut)"
flutter build apk --release

APK="$DUONG_APP/build/app/outputs/flutter-apk/app-release.apk"
if [ -f "$APK" ]; then
  printf '\n\033[32m===============================================\n XONG. File APK:\033[0m\n'
  echo " $APK"
  echo " ($(du -h "$APK" | cut -f1))"
  printf '\033[32m===============================================\033[0m\n\n'
  echo "Chep sang dien thoai roi bam vao de cai."
else
  canh "Build chay xong nhung khong thay file APK. Doc ky thong bao ben tren."
fi

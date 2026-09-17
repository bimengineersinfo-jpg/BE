# =============================================================================
#  BE 3D Site Viewer — dựng project và build APK (Windows / PowerShell)
# =============================================================================
#  Chạy: mở PowerShell tại thư mục này rồi gõ
#        .\chuan_bi.ps1
#
#  Script làm 5 việc:
#    1. flutter create ra bộ khung Android chuẩn (đúng phiên bản Flutter máy bạn)
#    2. chép code, assets và các file cấu hình của bộ này đè lên
#    3. TẢI HỘ hai thư viện JavaScript (model-viewer, qrcode) — đây là việc mà
#       máy dựng bộ này không làm được vì không ra được Internet
#    4. flutter pub get
#    5. flutter build apk --release
#
#  Muốn dừng trước bước build thì chạy:  .\chuan_bi.ps1 -KhongBuild
# =============================================================================
param(
    [switch]$KhongBuild,
    [string]$ThuMuc = "app"
)

$ErrorActionPreference = "Stop"
$goc = $PSScriptRoot

function Buoc($n, $chu) { Write-Host "`n[$n] $chu" -ForegroundColor Cyan }
# PowerShell khong tu dung lai khi lenh ngoai (flutter/gradle) bao loi, nen
# phai tu kiem ma tra ve. Thieu cai nay thi script bao "XONG" trong khi khong
# co file APK nao — mat thoi gian di tim nguyen nhan sai cho.
function KiemMaLoi($ten) {
    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "DUNG LAI: lenh '$ten' bao loi (ma $LASTEXITCODE)." -ForegroundColor Red
        Write-Host "Doc ky thong bao ngay ben tren — do la nguyen nhan that." -ForegroundColor Red
        Write-Host "Neu khong hieu, chup lai toan bo phan mau do va gui lai."
        exit 1
    }
}
function Xong($chu)     { Write-Host "    OK  $chu" -ForegroundColor Green }
function Canh($chu)     { Write-Host "    !!  $chu" -ForegroundColor Yellow }

# --- 0. Kiểm tra Flutter ------------------------------------------------------
Buoc 0 "Kiem tra Flutter"
try {
    $v = (flutter --version 2>&1 | Select-Object -First 1)
    Xong $v
} catch {
    Write-Host "KHONG TIM THAY 'flutter'." -ForegroundColor Red
    Write-Host "Hay cai Flutter va them vao PATH truoc. Xem file Huong_dan_cai_Flutter_VSCode_Windows.md"
    exit 1
}

# --- 1. Tạo bộ khung ----------------------------------------------------------
$duongApp = Join-Path $goc $ThuMuc
Buoc 1 "Tao bo khung Flutter tai: $duongApp"
if (Test-Path $duongApp) {
    Canh "Thu muc da ton tai — dung lai, khong tao de len."
} else {
    flutter create --org info.bimengineers --project-name be_3d_site_viewer `
        --platforms android,ios "$duongApp" | Out-Null
    KiemMaLoi "flutter create"
    Xong "Da tao"
}

# --- 2. Chép code của bộ này đè lên -------------------------------------------
Buoc 2 "Chep code va cau hinh"

Copy-Item (Join-Path $goc "pubspec.yaml") (Join-Path $duongApp "pubspec.yaml") -Force
Xong "pubspec.yaml"

$libDich = Join-Path $duongApp "lib"
Remove-Item (Join-Path $libDich "*.dart") -Force -ErrorAction SilentlyContinue
Copy-Item (Join-Path $goc "lib\*.dart") $libDich -Force
Xong "lib\ (5 file .dart)"

# flutter create sinh san test/widget_test.dart tham chieu lop MyApp (mac dinh).
# App nay dung lop AppBE3D nen file do bao loi do trong VS Code va lam
# `flutter test` that bai — khong chan build APK nhung du de nguoi dung tuong
# app hong. Xoa di cho sach.
$testCu = Join-Path $duongApp "test\widget_test.dart"
if (Test-Path $testCu) { Remove-Item $testCu -Force; Xong "da xoa test/widget_test.dart mac dinh" }

$wwwDich = Join-Path $duongApp "assets\www"
New-Item -ItemType Directory -Force -Path $wwwDich | Out-Null
Copy-Item (Join-Path $goc "assets\www\index.html") $wwwDich -Force
Xong "assets\www\index.html"

$manifestDich = Join-Path $duongApp "android\app\src\main\AndroidManifest.xml"
Copy-Item (Join-Path $goc "ghep_vao_project\android\app\src\main\AndroidManifest.xml") $manifestDich -Force
Xong "AndroidManifest.xml"

$xmlDich = Join-Path $duongApp "android\app\src\main\res\xml"
New-Item -ItemType Directory -Force -Path $xmlDich | Out-Null
Copy-Item (Join-Path $goc "ghep_vao_project\android\app\src\main\res\xml\network_security_config.xml") $xmlDich -Force
Xong "network_security_config.xml"

# --- 2b. MainActivity.kt: lấy đúng dòng package của project vừa tạo -----------
# Khong doan ten goi (package). Doc thang tu file ma flutter create sinh ra.
$mainCu = Get-ChildItem -Path (Join-Path $duongApp "android\app\src\main") `
    -Recurse -Filter "MainActivity.kt" -ErrorAction SilentlyContinue | Select-Object -First 1
if ($null -eq $mainCu) {
    Canh "Khong tim thay MainActivity.kt do flutter create sinh ra."
    Canh "Bo qua buoc nay. Hau qua: khong xin duoc quyen camera -> khong quet duoc QR."
    Canh "Phan xem mo hinh van chay binh thuong."
} else {
    $dongGoi = (Get-Content $mainCu.FullName | Where-Object { $_ -match '^\s*package\s+' } | Select-Object -First 1)
    if ([string]::IsNullOrWhiteSpace($dongGoi)) {
        Canh "MainActivity.kt khong co dong 'package'. Bo qua."
    } else {
        $mau = Get-Content (Join-Path $goc "ghep_vao_project\android\MainActivity.kt.mau") -Raw
        $moi = $mau -replace '// __GOI__', $dongGoi.Trim()
        Set-Content -Path $mainCu.FullName -Value $moi -Encoding UTF8
        Xong "MainActivity.kt ($($dongGoi.Trim()))"
    }
}

# --- 3. Tải hai thư viện JavaScript -------------------------------------------
Buoc 3 "Tai thu vien JavaScript (can mang)"

function TaiFile($url, $dich, $toiThieu, $ten) {
    if ((Test-Path $dich) -and ((Get-Item $dich).Length -gt $toiThieu)) {
        Xong "$ten da co san ($((Get-Item $dich).Length) byte)"
        return $true
    }
    try {
        Write-Host "    dang tai $ten ..."
        Invoke-WebRequest -Uri $url -OutFile $dich -UseBasicParsing -TimeoutSec 90
        $co = (Get-Item $dich).Length
        if ($co -lt $toiThieu) {
            Canh "$ten tai ve chi $co byte — nghi la sai file."
            return $false
        }
        Xong "$ten ($co byte)"
        return $true
    } catch {
        Canh "Khong tai duoc $ten : $_"
        return $false
    }
}

$okMv = TaiFile "https://ajax.googleapis.com/ajax/libs/model-viewer/3.5.0/model-viewer.min.js" `
                (Join-Path $wwwDich "model-viewer.min.js") 80000 "model-viewer.min.js"
$okQr = TaiFile "https://cdnjs.cloudflare.com/ajax/libs/qrcode-generator/1.4.4/qrcode.min.js" `
                (Join-Path $wwwDich "qrcode.min.js") 2000 "qrcode.min.js"

if (-not $okMv) {
    Write-Host ""
    Write-Host "DUNG LAI: thieu model-viewer.min.js thi app se khong hien duoc mo hinh." -ForegroundColor Red
    Write-Host "Hay tu tai file nay:" -ForegroundColor Red
    Write-Host "  https://ajax.googleapis.com/ajax/libs/model-viewer/3.5.0/model-viewer.min.js"
    Write-Host "roi dat vao: $wwwDich\model-viewer.min.js  — sau do chay lai script."
    exit 1
}
if (-not $okQr) {
    Canh "Thieu qrcode.min.js: van tao duoc noi dung moc (hien nguyen van de copy)"
    Canh "nhung khong ve duoc anh QR. Khong chan build."
    # Tao file giu cho de asset khong bi thieu.
    Set-Content -Path (Join-Path $wwwDich "qrcode.min.js") -Value "/* chua tai duoc */" -Encoding UTF8
}

# --- 4 & 5. pub get + build ---------------------------------------------------
Push-Location $duongApp
try {
    Buoc 4 "flutter pub get"
    flutter pub get
    KiemMaLoi "flutter pub get"
    Xong "Xong"

    if ($KhongBuild) {
        Write-Host "`nDa chuan bi xong. Chay tiep bang tay:" -ForegroundColor Green
        Write-Host "  cd $duongApp"
        Write-Host "  flutter run              # chay thu qua cap USB"
        Write-Host "  flutter build apk --release"
        exit 0
    }

    Buoc 5 "flutter build apk --release  (lan dau co the mat 5-15 phut)"
    flutter build apk --release
    KiemMaLoi "flutter build apk"

    $apk = Join-Path $duongApp "build\app\outputs\flutter-apk\app-release.apk"
    if (Test-Path $apk) {
        $mb = [math]::Round((Get-Item $apk).Length / 1MB, 1)
        Write-Host ""
        Write-Host "===============================================" -ForegroundColor Green
        Write-Host " XONG. File APK:" -ForegroundColor Green
        Write-Host " $apk"
        Write-Host " ($mb MB)"
        Write-Host "===============================================" -ForegroundColor Green
        Write-Host ""
        Write-Host "Chep sang dien thoai roi bam vao de cai."
        Write-Host "Android se hoi 'cai app tu nguon khong xac dinh' -> chon Cho phep."
    } else {
        Canh "Build chay xong nhung khong thay file APK. Doc ky thong bao ben tren."
    }
} finally {
    Pop-Location
}

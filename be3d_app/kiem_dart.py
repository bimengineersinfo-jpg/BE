# -*- coding: utf-8 -*-
"""Kiem tra tinh nhat quan cua file .dart ma KHONG can trinh bien dich.

Vi sao can: may nay khong co Flutter/Dart, nen khong the `dart analyze`. Kiem
tay bang mat de sot. Bo quet duoi day khong phai trinh bien dich, nhung no doc
DUNG cu phap chuoi cua Dart — ke ca chuoi tho r'''...''', chuoi ba nhay, va
noi suy ${...} long nhau — nen dem ngoac dang tin.

Bai hoc: ban dau toi dem bang bieu thuc chinh quy va no bao SAI hai file. Ly
do la '//' trong chuoi 'http://127.0.0.1' bi hieu nham la chu thich. Cong cu
kiem ma tu no sai thi con te hon khong kiem, vi no lam minh di sua code dung.
"""
import io
import sys
import glob


def quet(src):
    """Tra ve (ma_khong_co_chuoi_va_chu_thich, danh_sach_loi)."""
    ra = []
    loi = []
    i, n = 0, len(src)
    dong = 1
    # ngan xep cho noi suy: moi lan gap ${ trong chuoi thi day trang thai chuoi
    stack_chuoi = []

    def la(s, k=0):
        return src.startswith(s, i + k)

    while i < n:
        c = src[i]
        if c == '\n':
            dong += 1
            ra.append('\n')
            i += 1
            continue

        # --- chu thich ---
        if la('//'):
            while i < n and src[i] != '\n':
                i += 1
            continue
        if la('/*'):
            sau = src.find('*/', i + 2)
            if sau < 0:
                loi.append('dong %d: chu thich /* khong duoc dong' % dong)
                break
            dong += src.count('\n', i, sau)
            i = sau + 2
            continue

        # --- chuoi ---
        tho = False
        j = i
        if c == 'r' and i + 1 < n and src[i + 1] in '\'"':
            tho = True
            j = i + 1
        if src[j] in '\'"':
            nhay = src[j]
            ba = src.startswith(nhay * 3, j)
            mo = nhay * 3 if ba else nhay
            k = j + len(mo)
            while k < n:
                if not tho and src[k] == '\\':
                    k += 2
                    continue
                if not tho and src.startswith('${', k):
                    # Noi suy: phai dem ngoac ben trong nhu ma thuong.
                    sau_ns = _bo_qua_noi_suy(src, k + 2)
                    if sau_ns < 0:
                        loi.append('dong %d: ${ trong chuoi khong duoc dong' % dong)
                        return ''.join(ra), loi
                    # Giu lai phan trong ${} de dem ngoac cho dung
                    ra.append(' ')
                    trong, _ = quet(src[k + 2:sau_ns - 1])
                    ra.append(trong)
                    ra.append(' ')
                    dong += src.count('\n', k, sau_ns)
                    k = sau_ns
                    continue
                if src.startswith(mo, k):
                    k += len(mo)
                    break
                if src[k] == '\n':
                    dong += 1
                    if not ba:
                        loi.append('dong %d: chuoi mot dong bi xuong dong' % dong)
                        return ''.join(ra), loi
                k += 1
            else:
                loi.append('dong %d: chuoi khong duoc dong' % dong)
                return ''.join(ra), loi
            ra.append(' ')
            i = k
            continue

        ra.append(c)
        i += 1

    return ''.join(ra), loi


def _bo_qua_noi_suy(src, i):
    """Tra ve vi tri ngay SAU dau } dong cua ${ ... }."""
    sau = 1
    n = len(src)
    while i < n and sau:
        c = src[i]
        if c in '\'"':
            nhay = c
            i += 1
            while i < n:
                if src[i] == '\\':
                    i += 2
                    continue
                if src[i] == nhay:
                    i += 1
                    break
                i += 1
            continue
        if c == '{':
            sau += 1
        elif c == '}':
            sau -= 1
        i += 1
    return i if sau == 0 else -1


def kiem(f):
    src = io.open(f, encoding='utf-8').read()
    ma, loi = quet(src)
    dem = {c: ma.count(c) for c in '{}()[]'}
    can = (dem['{'] == dem['}'] and dem['('] == dem[')'] and dem['['] == dem[']'])

    # Do sau ngoac khong duoc am o bat cu diem nao (bat truong hop dong thua)
    sau, am = 0, False
    for c in ma:
        if c in '{([':
            sau += 1
        elif c in '})]':
            sau -= 1
            if sau < 0:
                am = True
                break

    # Vai kiem tra rieng cho Dart
    canh = []

    # BAY DA DINH THAT: viet '\${...}' trong chuoi Dart thi \$ la ky tu dola
    # NGUYEN VAN, chuoi ra van ban tho thay vi noi suy -> duong dan file thanh
    # "${d.path}/x.json" theo dung nghia den. Khong sap, khong bao loi, chi
    # ghi sai cho. Bo dem ngoac khong bat duoc vi cu phap van hop le.
    # (Toi dinh loi nay khi dung heredoc de sinh code.)
    for i, d in enumerate(src.split('\n'), 1):
        if '\\${' in d:
            canh.append('dong %d: co \\${...} — dau $ bi escape nen chuoi KHONG noi suy: %s'
                        % (i, d.strip()[:60]))
    if 'import ' in src:
        for d in src.split('\n'):
            d = d.strip()
            if d.startswith('import ') and not d.endswith(';'):
                canh.append('import khong ket thuc bang ; -> ' + d[:50])
    ok = can and not am and not loi and not canh
    trang_thai = 'OK  ' if ok else 'SAI '
    print('%s %-28s %s' % (trang_thai, f, dem))
    for x in loi + canh:
        print('       -> ' + x)
    if am:
        print('       -> co dau dong ngoac thua (do sau am)')
    return ok


if __name__ == '__main__':
    ds = sorted(glob.glob('lib/*.dart'))
    tot = all(kiem(f) for f in ds)
    print('\n=== %d file, %s ===' % (len(ds), 'tat ca nhat quan' if tot else 'CO FILE SAI'))
    sys.exit(0 if tot else 1)

# -*- coding: utf-8 -*-
"""
BÀI TẬP KỸ NĂNG 2 - Phân mảnh ngang NGUYÊN THỦY & DẪN XUẤT
CSDL quản lý bán hàng:

    NHANVIEN ( MANV , TENNV , NGAYSINH , TUOI , GIOITINH )
    DIACHI   ( MANV , DIACHI )
    MATHANG  ( MAMH , GIABAN , CHUNGLOAI , MANV , THOIDIEMBAN )

Chương trình minh hoạ:
  1) Lược đồ quan hệ chuyển từ ER
  2) Hai ứng dụng -> tập vị từ đơn giản Pr
  3) COM_MIN -> tập vị từ đầy đủ và cực tiểu Pr'
  4) Sinh hội sơ cấp M -> phân mảnh ngang NGUYÊN THỦY trên NHANVIEN
  5) Phân mảnh ngang DẪN XUẤT (nửa nối) trên MATHANG và DIACHI
  6) Kiểm tra đầy đủ / tái thiết / tách biệt + lợi ích nối cục bộ

Chạy:  python phanmanh_banhang.py
"""

import sys
from itertools import product

# Console Windows mặc định dùng cp1252/cp437 -> ép UTF-8 để in được tiếng Việt
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

# ----------------------------------------------------------------------
# DỮ LIỆU: ba quan hệ toàn cục (tuổi tính đến 31/12/2025)
# ----------------------------------------------------------------------
NV_COLS = ["MANV", "TENNV", "NGAYSINH", "TUOI", "GIOITINH"]
NHANVIEN = [
    ("NV01", "Nguyễn Văn An", "12/05/1998", 27, "Nam"),
    ("NV02", "Trần Thị Bích", "03/11/1996", 29, "Nữ"),
    ("NV03", "Lê Văn Cường",  "20/02/1985", 40, "Nam"),
    ("NV04", "Phạm Thị Dung", "15/07/1988", 37, "Nữ"),
    ("NV05", "Hoàng Văn Em",  "30/09/2000", 25, "Nam"),
    ("NV06", "Vũ Thị Hoa",    "08/12/1983", 42, "Nữ"),
]

DC_COLS = ["MANV", "DIACHI"]
DIACHI = [
    ("NV01", "12 Lê Lợi, Hà Nội"),
    ("NV01", "45 Trần Phú, Bắc Ninh"),
    ("NV02", "8 Nguyễn Trãi, Hà Nội"),
    ("NV03", "102 Hùng Vương, Đà Nẵng"),
    ("NV03", "7 Bạch Đằng, Huế"),
    ("NV04", "56 Lý Thường Kiệt, Đà Nẵng"),
    ("NV05", "33 CMT8, TP. Hồ Chí Minh"),
    ("NV05", "19 Võ Văn Tần, TP. Hồ Chí Minh"),
    ("NV06", "77 Nguyễn Huệ, Cần Thơ"),
]

MH_COLS = ["MAMH", "GIABAN", "CHUNGLOAI", "MANV", "THOIDIEMBAN"]
MATHANG = [
    ("MH01",  7500000, "Điện lạnh", "NV01", "05/03/2025 09:15"),
    ("MH02",  6200000, "Điện lạnh", "NV01", "07/03/2025 14:30"),
    ("MH03", 12000000, "Điện tử",   "NV05", "08/03/2025 10:00"),
    ("MH04", 25000000, "Điện tử",   "NV05", "10/03/2025 16:45"),
    ("MH05",  1200000, "Gia dụng",  "NV03", "11/03/2025 08:20"),
    ("MH06",  3400000, "Gia dụng",  "NV03", "12/03/2025 11:05"),
    ("MH07", 15900000, "Điện tử",   "NV02", "13/03/2025 09:40"),
    ("MH08",  4800000, "Gia dụng",  "NV02", "14/03/2025 15:10"),
    ("MH09",  9900000, "Điện lạnh", "NV04", "15/03/2025 10:25"),
    ("MH10",  5600000, "Gia dụng",  "NV04", "16/03/2025 13:50"),
    ("MH11",  2750000, "Gia dụng",  "NV06", "17/03/2025 08:55"),
    ("MH12",  1850000, "Điện tử",   "NV06", "18/03/2025 17:20"),
]

NV = {c: i for i, c in enumerate(NV_COLS)}
DC = {c: i for i, c in enumerate(DC_COLS)}
MH = {c: i for i, c in enumerate(MH_COLS)}


class Pred:
    """Vị từ đơn giản: thuộc_tính θ giá_trị"""

    def __init__(self, name, attr, op, value, func, acc, neg_text):
        self.name, self.attr, self.op, self.value = name, attr, op, value
        self.func = func          # hàm đánh giá trên một bộ
        self.acc = acc            # tần số truy xuất (lần/tháng)
        self.neg_text = neg_text  # dạng đọc được của phủ định vị từ

    def __call__(self, t):
        return self.func(t)

    def __str__(self):
        return "%s %s %s" % (self.attr, self.op, self.value)


# ----------------------------------------------------------------------
# CÂU 2a: Tập vị từ đơn giản Pr (sinh từ 2 ứng dụng, đặt trên NHANVIEN)
# ----------------------------------------------------------------------
q1 = Pred("q1", "GIOITINH", "=",  "'Nam'", lambda t: t[NV["GIOITINH"]] == "Nam", 60,
          "GIOITINH = 'Nữ'")     # miền chỉ 2 giá trị -> ¬q1 ⇔ q2
q2 = Pred("q2", "GIOITINH", "=",  "'Nữ'",  lambda t: t[NV["GIOITINH"]] == "Nữ",  55,
          "GIOITINH = 'Nam'")
q3 = Pred("q3", "TUOI",     "<=", "30",    lambda t: t[NV["TUOI"]] <= 30,        40,
          "TUOI > 30")           # hai khoảng bù nhau -> ¬q3 ⇔ q4
q4 = Pred("q4", "TUOI",     ">",  "30",    lambda t: t[NV["TUOI"]] >  30,        20,
          "TUOI <= 30")

Pr = [q1, q2, q3, q4]

# Tập suy dẫn I: cặp vị từ bù nhau -> vị từ thứ hai luôn là phủ định của vị từ đầu
IMPLICATIONS = [("q1", "q2"), ("q3", "q4")]


def partition(rows, pred):
    """Phân hoạch tập bộ thành (thỏa, không thỏa)."""
    yes = [t for t in rows if pred(t)]
    no = [t for t in rows if not pred(t)]
    return yes, no


def com_min(rows, preds):
    """
    COM_MIN - tìm tập vị từ ĐẦY ĐỦ và CỰC TIỂU.

    Một vị từ được nhận vào Pr' nếu nó phân hoạch ít nhất một mảnh hiện có
    thành hai phần KHÁC RỖNG và được các ứng dụng truy xuất khác nhau
    (Quy tắc cơ bản). Vị từ tương đương phủ định của vị từ đã có (theo tập
    suy dẫn I) là KHÔNG LIÊN QUAN -> bị loại.
    """
    equiv_neg = {b: a for a, b in IMPLICATIONS}   # q2 -> q1 ; q4 -> q3
    Pr_prime, F, log = [], [rows], []

    for p in preds:
        # (a) kiểm tra tính liên quan theo tập suy dẫn I
        partner = equiv_neg.get(p.name)
        if partner and partner in [x.name for x in Pr_prime]:
            log.append("   - %s (%s): tương đương ¬%s theo I -> KHÔNG LIÊN QUAN, loại"
                       % (p.name, p, partner))
            continue

        # (b) kiểm tra Quy tắc cơ bản: có phân hoạch được mảnh nào không?
        newF, splits = [], 0
        for f in F:
            yes, no = partition(f, p)
            if yes and no:
                splits += 1
                newF.extend([yes, no])
            else:
                newF.append(f)

        if splits == 0:
            log.append("   - %s (%s): không phân hoạch được mảnh nào -> loại" % (p.name, p))
            continue

        Pr_prime.append(p)
        F = newF
        log.append("   + %s (%s): phân hoạch %d mảnh -> nhận vào Pr'  (acc = %d)"
                   % (p.name, p, splits, p.acc))

    return Pr_prime, F, log


def minterms(preds):
    """Sinh tập hội sơ cấp M; loại các hội sơ cấp mâu thuẫn (không có bộ nào thỏa)."""
    out = []
    for signs in product([True, False], repeat=len(preds)):
        rows = [t for t in NHANVIEN
                if all(p(t) == s for p, s in zip(preds, signs))]
        expr = " ∧ ".join(("" if s else "¬") + p.name for p, s in zip(preds, signs))
        readable = " ∧ ".join(("%s" % p) if s else p.neg_text
                              for p, s in zip(preds, signs))
        out.append({"signs": signs, "expr": expr, "readable": readable, "rows": rows})
    return out


def semijoin(member_rows, member_key_idx, owner_rows, owner_key_idx):
    """S ⋉ R : lấy các bộ của S có bộ đối tác trong R theo thuộc tính nối."""
    keys = {t[owner_key_idx] for t in owner_rows}
    return [t for t in member_rows if t[member_key_idx] in keys]


def main():
    line = "=" * 78

    # ---------------- CÂU 1 ----------------
    print(line)
    print("[CÂU 1] LƯỢC ĐỒ QUAN HỆ (chuyển từ lược đồ ER)")
    print(line)
    print("   NHANVIEN ( MANV , TENNV , NGAYSINH , TUOI , GIOITINH )      PK: MANV")
    print("   DIACHI   ( MANV , DIACHI )                    PK: (MANV, DIACHI)")
    print("                                                 FK: MANV -> NHANVIEN")
    print("   MATHANG  ( MAMH , GIABAN , CHUNGLOAI , MANV , THOIDIEMBAN ) PK: MAMH")
    print("                                                 FK: MANV -> NHANVIEN")
    print()
    print("   - DIACHI đa trị      -> tách thành quan hệ riêng")
    print("   - TUOI suy diễn      -> tính từ NGAYSINH (mốc 31/12/2025)")
    print("   - BAN là liên kết 1:N -> nhúng MANV + THOIDIEMBAN vào phía N (MATHANG)")
    print("   Số bộ: NHANVIEN = %d , DIACHI = %d , MATHANG = %d"
          % (len(NHANVIEN), len(DIACHI), len(MATHANG)))

    # ---------------- CÂU 2a: Pr ----------------
    print("\n" + line)
    print("[CÂU 2a] TẬP VỊ TỪ ĐƠN GIẢN Pr (sinh từ 2 ứng dụng)")
    print(line)
    print("   ƯD1 - Thống kê doanh số theo tổ bán hàng (NHANVIEN ⋈ MATHANG)")
    print("   ƯD2 - Quản lý hồ sơ nhân viên theo nhóm tuổi (NHANVIEN ⋈ DIACHI)")
    print()
    for p in Pr:
        yes, no = partition(NHANVIEN, p)
        print("   %s : %-22s  |thỏa| = %d , |không thỏa| = %d , acc = %d"
              % (p.name, str(p), len(yes), len(no), p.acc))
    print("   Tập suy dẫn I : q1 ⇔ ¬q2  ;  q3 ⇔ ¬q4")

    # ---------------- CÂU 2b: COM_MIN ----------------
    print("\n" + line)
    print("[CÂU 2b] THUẬT TOÁN COM_MIN -> Pr' ĐẦY ĐỦ VÀ CỰC TIỂU")
    print(line)
    Pr_prime, F, log = com_min(NHANVIEN, Pr)
    for l in log:
        print(l)
    print("\n   ==> Pr' = { %s }" % " , ".join("%s: %s" % (p.name, p) for p in Pr_prime))

    # ---------------- CÂU 2c: hội sơ cấp ----------------
    print("\n" + line)
    print("[CÂU 2c] TẬP HỘI SƠ CẤP M")
    print(line)
    all_m = minterms(Pr_prime)
    kept = [m for m in all_m if m["rows"]]
    print("   Số tổ hợp tối đa = 2^%d = %d" % (len(Pr_prime), len(all_m)))
    for m in all_m:
        tag = "THỎA ĐƯỢC" if m["rows"] else "MÂU THUẪN / RỖNG"
        print("   %-14s = %-30s  %s (%d bộ)"
              % (m["expr"], m["readable"], tag, len(m["rows"])))
    print("\n   ==> |M| = %d hội sơ cấp thỏa được" % len(kept))

    # ---------------- Phân mảnh NGUYÊN THỦY ----------------
    print("\n" + line)
    print("[PHÂN MẢNH NGANG NGUYÊN THỦY] quan hệ CHỦ: NHANVIEN")
    print(line)
    nv_frags = []
    for i, m in enumerate(kept, start=1):
        ids = [t[NV["MANV"]] for t in m["rows"]]
        nv_frags.append(m["rows"])
        print("   NHANVIEN%d = σ(%s)(NHANVIEN)" % (i, m["readable"]))
        print("             = {%s}   (%d bộ)" % (", ".join(ids), len(ids)))

    # ---------------- Phân mảnh DẪN XUẤT ----------------
    print("\n" + line)
    print("[PHÂN MẢNH NGANG DẪN XUẤT] quan hệ THÀNH VIÊN: MATHANG , DIACHI")
    print(line)
    mh_frags, dc_frags = [], []
    for i, owner in enumerate(nv_frags, start=1):
        fm = semijoin(MATHANG, MH["MANV"], owner, NV["MANV"])
        fd = semijoin(DIACHI, DC["MANV"], owner, NV["MANV"])
        mh_frags.append(fm)
        dc_frags.append(fd)
        print("   MATHANG%d = MATHANG ⋉ NHANVIEN%d = {%s}   (%d bộ)"
              % (i, i, ", ".join(str(t[MH["MAMH"]]) for t in fm), len(fm)))
    print()
    for i, fd in enumerate(dc_frags, start=1):
        print("   DIACHI%d  = DIACHI ⋉ NHANVIEN%d  = {%s}   (%d bộ)"
              % (i, i, ", ".join("%s/%s" % (t[0], t[1].split(",")[0]) for t in fd), len(fd)))

    # ---------------- Kiểm tra tính đúng đắn ----------------
    print("\n" + line)
    print("[KIỂM TRA TÍNH ĐÚNG ĐẮN]")
    print(line)

    def check(ten, frags, goc, key_idx):
        tong = sum(len(f) for f in frags)
        seen = {}
        for f in frags:
            for t in f:
                k = t[key_idx] if ten != "DIACHI" else t
                seen[k] = seen.get(k, 0) + 1
        goc_keys = {(t[key_idx] if ten != "DIACHI" else t) for t in goc}
        dup = [k for k, v in seen.items() if v > 1]
        print("   %-9s Đầy đủ   : %2d bộ trong các mảnh / %2d bộ gốc  -> %s"
              % (ten, tong, len(goc), "ĐẠT" if tong == len(goc) else "SAI"))
        print("   %-9s Tái thiết: %s = %s -> %s"
              % ("", ten, " ∪ ".join("%s%d" % (ten, i) for i in range(1, len(frags) + 1)),
                 "ĐẠT" if set(seen) == goc_keys else "SAI"))
        print("   %-9s Tách biệt: số bộ nằm trong >1 mảnh = %d -> %s"
              % ("", len(dup), "ĐẠT" if not dup else "SAI"))

    check("NHANVIEN", nv_frags, NHANVIEN, NV["MANV"])
    check("MATHANG", mh_frags, MATHANG, MH["MAMH"])
    check("DIACHI", dc_frags, DIACHI, 0)

    # ---------------- Lợi ích của phân mảnh dẫn xuất ----------------
    print("\n" + line)
    print("[LỢI ÍCH] PHÉP NỐI PHÂN PHỐI ĐƯỢC TRÊN HỢP")
    print(line)
    local = sum(len([1 for n in nv_frags[i] for m in mh_frags[i]
                     if n[NV["MANV"]] == m[MH["MANV"]]]) for i in range(len(nv_frags)))
    cross = sum(len([1 for n in nv_frags[i] for m in mh_frags[j]
                     if n[NV["MANV"]] == m[MH["MANV"]]])
                for i in range(len(nv_frags)) for j in range(len(mh_frags)) if i != j)
    toancuc = len([1 for n in NHANVIEN for m in MATHANG
                   if n[NV["MANV"]] == m[MH["MANV"]]])
    print("   NHANVIEN ⋈ MATHANG (toàn cục)          = %d bộ" % toancuc)
    print("   ∪ (NHANVIEN_i ⋈ MATHANG_i) - nối cục bộ = %d bộ -> %s"
          % (local, "BẰNG NHAU, tái thiết ĐẠT" if local == toancuc else "SAI"))
    print("   Σ (NHANVIEN_i ⋈ MATHANG_j), i ≠ j       = %d bộ -> %s"
          % (cross, "RỖNG, không cần truyền dữ liệu liên trạm"
             if cross == 0 else "SAI"))
    print(line)


if __name__ == "__main__":
    main()

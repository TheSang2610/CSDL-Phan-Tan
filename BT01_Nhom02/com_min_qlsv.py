# -*- coding: utf-8 -*-
"""
BÀI TẬP KỸ NĂNG 1 - Phân mảnh ngang cơ sở quan hệ QLSV(MA,HT,QQ,NS,GT,DT,TB)

Chương trình minh hoạ 4 câu:
  1) Sinh tập vị từ đơn giản Pr từ 2 ứng dụng
  2) Chạy COM_MIN -> tập vị từ đầy đủ và cực tiểu Pr'
  3) Sinh tập hội sơ cấp M (loại các hội mâu thuẫn)
  4) Phân mảnh ngang + kiểm tra đầy đủ / tái thiết / tách biệt

Chạy:  python com_min_qlsv.py
"""

from itertools import product

# ----------------------------------------------------------------------
# DỮ LIỆU: quan hệ toàn cục QLSV
# ----------------------------------------------------------------------
COLS = ["MA", "HT", "QQ", "NS", "GT", "DT", "TB"]
QLSV = [
    ("SV01", "Nguyễn Văn An",  "Miền Bắc",   2004, "Nam", "Kinh",  8.5),
    ("SV02", "Trần Thị Bình",  "Miền Bắc",   2004, "Nữ",  "Kinh",  7.2),
    ("SV03", "Lê Văn Cường",   "Miền Trung", 2003, "Nam", "Kinh",  9.0),
    ("SV04", "Phạm Thị Dung",  "Miền Trung", 2004, "Nữ",  "Kinh",  6.8),
    ("SV05", "Hoàng Văn Em",   "Miền Nam",   2005, "Nam", "Kinh",  8.2),
    ("SV06", "Vũ Thị Hoa",     "Miền Nam",   2004, "Nữ",  "Hoa",   7.5),
    ("SV07", "Đặng Văn Giang", "Miền Bắc",   2003, "Nam", "Tày",   8.0),
    ("SV08", "Bùi Thị Hạnh",   "Miền Trung", 2004, "Nữ",  "Mường", 8.9),
    ("SV09", "Ngô Văn Khoa",   "Miền Trung", 2003, "Nam", "Ê Đê",  6.5),
    ("SV10", "Đỗ Thị Lan",     "Miền Nam",   2005, "Nữ",  "Khmer", 7.9),
    ("SV11", "Lý Văn Minh",    "Miền Bắc",   2004, "Nam", "Kinh",  5.5),
    ("SV12", "Trịnh Thị Nga",  "Miền Nam",   2003, "Nữ",  "Kinh",  9.2),
]
IDX = {c: i for i, c in enumerate(COLS)}


class Pred:
    """Vị từ đơn giản: thuộc_tính θ giá_trị"""

    def __init__(self, name, attr, op, value, func):
        self.name, self.attr, self.op, self.value, self.func = name, attr, op, value, func

    def __call__(self, t):
        return self.func(t)

    def __str__(self):
        return "%s %s %s" % (self.attr, self.op, self.value)


# ----------------------------------------------------------------------
# CÂU 1: Tập vị từ đơn giản Pr (sinh từ 2 ứng dụng)
# ----------------------------------------------------------------------
p1 = Pred("p1", "TB", ">=", "8.0",         lambda t: t[IDX["TB"]] >= 8.0)
p2 = Pred("p2", "TB", "<",  "8.0",         lambda t: t[IDX["TB"]] < 8.0)
p3 = Pred("p3", "QQ", "=",  "'Miền Bắc'",  lambda t: t[IDX["QQ"]] == "Miền Bắc")
p4 = Pred("p4", "QQ", "=",  "'Miền Trung'", lambda t: t[IDX["QQ"]] == "Miền Trung")
p5 = Pred("p5", "QQ", "=",  "'Miền Nam'",  lambda t: t[IDX["QQ"]] == "Miền Nam")

Pr = [p1, p2, p3, p4, p5]

# Ứng dụng -> vị từ mà ứng dụng dùng để truy xuất
APPS = {
    "ƯD1.1 Xét học bổng (TB>=8.0)": p1,
    "ƯD1.2 Cảnh báo học vụ (TB<8.0)": p2,
    "ƯD2.1 Cơ sở phía Bắc": p3,
    "ƯD2.2 Cơ sở miền Trung": p4,
    "ƯD2.3 Cơ sở phía Nam": p5,
}


def signature(tuple_):
    """'Dấu vân tay truy xuất' của một bộ: tập ứng dụng truy xuất tới bộ đó."""
    return tuple(sorted(a for a, p in APPS.items() if p(tuple_)))


def fragments_of(pred_set, rows):
    """Phân hoạch rows theo mọi tổ hợp giá trị chân lý của pred_set."""
    parts = {}
    for t in rows:
        key = tuple(p(t) for p in pred_set)
        parts.setdefault(key, []).append(t)
    return parts


def is_complete(pred_set, rows):
    """Rule 1: mọi bộ trong cùng một mảnh phải được mọi ứng dụng truy xuất như nhau."""
    for part in fragments_of(pred_set, rows).values():
        if len({signature(t) for t in part}) > 1:
            return False
    return True


def is_relevant(p, pred_set, rows):
    """p liên quan nếu thêm p vào pred_set thực sự chia nhỏ ít nhất một mảnh."""
    before = len(fragments_of(pred_set, rows))
    after = len(fragments_of(pred_set + [p], rows))
    return after > before


# ----------------------------------------------------------------------
# CÂU 2: Thuật toán COM_MIN
# ----------------------------------------------------------------------
def com_min(R, Pr):
    remaining = list(Pr)
    Pr_prime = []
    trace = []

    # Bước 2: chọn vị từ đầu tiên phân hoạch R theo Rule 1
    for p in list(remaining):
        if is_relevant(p, [], R):
            Pr_prime.append(p)
            remaining.remove(p)
            trace.append("Chọn %s (%s): phân hoạch R -> Pr' = {%s}"
                         % (p.name, p, ", ".join(q.name for q in Pr_prime)))
            break

    # Bước 3: lặp cho tới khi Pr' đầy đủ
    while not is_complete(Pr_prime, R):
        picked = None
        for p in list(remaining):
            if is_relevant(p, Pr_prime, R):
                picked = p
                break
        if picked is None:
            break
        Pr_prime.append(picked)
        remaining.remove(picked)
        trace.append("Thêm %s (%s): phân hoạch tiếp một mảnh -> Pr' = {%s}"
                     % (picked.name, picked, ", ".join(q.name for q in Pr_prime)))

        # loại vị từ không còn liên quan trong Pr'
        for q in list(Pr_prime):
            others = [x for x in Pr_prime if x is not q]
            if not is_relevant(q, others, R):
                Pr_prime.remove(q)
                trace.append("  -> loại %s khỏi Pr' (không liên quan)" % q.name)

    for p in remaining:
        trace.append("Bỏ %s (%s): không liên quan / thừa theo tập suy dẫn I"
                     % (p.name, p))
    return Pr_prime, trace


# ----------------------------------------------------------------------
# CÂU 3 + 4: hội sơ cấp và phân mảnh
# ----------------------------------------------------------------------
def minterms(pred_set, rows):
    """Sinh 2^n hội sơ cấp, đánh dấu hội mâu thuẫn (không bộ nào thoả)."""
    out = []
    for signs in product([True, False], repeat=len(pred_set)):
        expr = " ∧ ".join(("" if s else "¬") + p.name
                          for p, s in zip(pred_set, signs))
        readable = " ∧ ".join(("" if s else "NOT ") + str(p)
                              for p, s in zip(pred_set, signs))
        frag = [t for t in rows
                if all(p(t) == s for p, s in zip(pred_set, signs))]
        out.append({"signs": signs, "expr": expr, "readable": readable,
                    "rows": frag, "satisfiable": len(frag) > 0})
    return out


def main():
    line = "=" * 74
    print(line)
    print("BÀI TẬP KỸ NĂNG 1 — PHÂN MẢNH NGANG CƠ SỞ QUAN HỆ QLSV")
    print(line)

    print("\n[CÂU 1] TẬP VỊ TỪ ĐƠN GIẢN Pr")
    for p in Pr:
        print("   %s : %s" % (p.name, p))
    print("   Pr = {%s}" % ", ".join(p.name for p in Pr))
    print("   Tập suy dẫn I: p1 <=> ¬p2 ; p3,p4,p5 đôi một loại trừ ;")
    print("                  p3 ∨ p4 ∨ p5 ≡ TRUE  =>  p5 <=> ¬p3 ∧ ¬p4")

    print("\n[CÂU 2] THUẬT TOÁN COM_MIN")
    Pr_prime, trace = com_min(QLSV, Pr)
    for step in trace:
        print("   " + step)
    print("   => Pr' = {%s}" % ", ".join("%s: %s" % (p.name, p) for p in Pr_prime))
    print("   Đầy đủ (complete) : %s" % is_complete(Pr_prime, QLSV))
    print("   Cực tiểu (minimal): %s"
          % all(is_relevant(p, [q for q in Pr_prime if q is not p], QLSV)
                for p in Pr_prime))

    print("\n[CÂU 3] TẬP HỘI SƠ CẤP M")
    ms = minterms(Pr_prime, QLSV)
    kept = [m for m in ms if m["satisfiable"]]
    print("   Số tổ hợp tối đa: 2^%d = %d" % (len(Pr_prime), len(ms)))
    for m in ms:
        if m["satisfiable"]:
            print("   [GIỮ ] %-18s : %s" % (m["expr"], m["readable"]))
        else:
            print("   [LOẠI] %-18s : mâu thuẫn theo I (không bộ nào thoả)" % m["expr"])
    print("   => |M| = %d" % len(kept))

    print("\n[CÂU 4] PHÂN MẢNH NGANG CƠ SỞ")
    total = 0
    seen = {}
    for i, m in enumerate(kept, start=1):
        ids = [t[IDX["MA"]] for t in m["rows"]]
        total += len(ids)
        for k in ids:
            seen[k] = seen.get(k, 0) + 1
        print("   QLSV%d = σ(%s)(QLSV)" % (i, m["readable"]))
        print("          = {%s}   (%d bộ)" % (", ".join(ids), len(ids)))

    print("\n   KIỂM TRA TÍNH ĐÚNG ĐẮN")
    print("   - Đầy đủ   : %d bộ trong các mảnh / %d bộ gốc -> %s"
          % (total, len(QLSV), "ĐẠT" if total == len(QLSV) else "SAI"))
    print("   - Tái thiết: QLSV = %s -> %s"
          % (" ∪ ".join("QLSV%d" % i for i in range(1, len(kept) + 1)),
             "ĐẠT" if set(seen) == {t[IDX["MA"]] for t in QLSV} else "SAI"))
    dup = [k for k, v in seen.items() if v > 1]
    print("   - Tách biệt: số bộ nằm trong >1 mảnh = %d -> %s"
          % (len(dup), "ĐẠT" if not dup else "SAI"))
    print(line)


if __name__ == "__main__":
    main()

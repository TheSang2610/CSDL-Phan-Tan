# BẢNG THEO DÕI YÊU CẦU ĐỀ TÀI CUỐI KỲ

> Đối chiếu từng mục trong **"YÊU CẦU NỘI DUNG TRONG CUỐN BÁO CÁO"** với việc đã làm.
> Cập nhật cột *Trạng thái* mỗi khi xong một mục.
>
> ✅ xong · 🔄 đang làm · ⬜ chưa làm · ❗ cần bạn cung cấp

---

## A. YÊU CẦU CHUNG (áp dụng mọi đề tài)

| # | Yêu cầu | Đáp ứng bằng | Trạng thái |
|---|---|---|---|
| A1 | Có **2–4 site** | 3 site: `KHO_A`, `KHO_B`, `KHO_C` | ✅ đã cài 3/3 |
| A2 | **Phân mảnh** | Ngang **nguyên thủy** (`TonKho`) + **dẫn xuất** (`ChiTietNhap`, `ChiTietXuat`) | ✅ script `01`–`03` |
| A3 | **Replication** | Transactional Replication danh mục, Publisher = KHO_A | ✅ script `06` đã chạy thật |
| A4 | **Transaction** | Giao tác phân tán 2PC qua MS DTC | ✅ script `07` đã chạy thật |
| A5 | **Đồng bộ dữ liệu** | Replication danh mục + giao tác phân tán khi điều chuyển | ✅ script `06`, `07` |
| A6 | ≥1 **phân mảnh** | Có 2 loại (nguyên thủy + dẫn xuất) | ✅ |
| A7 | ≥1 **replication** | Transactional, push subscription | ✅ |
| A8 | ≥1 **distributed transaction** | Điều chuyển 50 sản phẩm KHO_A → KHO_B | ✅ T1 đã chạy |
| A9 | ≥1 **tình huống concurrency** | 4 kịch bản C1–C4: lost update, UPDLOCK, rowversion, deadlock 1205 | ✅ script `08` **đã chạy thật** |
| A10 | ≥1 **distributed query** | View `v_TonKho_ToanHeThong` + `sp_TonKhoToanHeThong` (dynamic) | ✅ script `09` **đã chạy thật** |

## B. YÊU CẦU RIÊNG ĐỀ TÀI 2 — Quản lý kho vật tư đa chi nhánh

| # | Yêu cầu | Đáp ứng bằng | Trạng thái |
|---|---|---|---|
| B1 | Bảng `VatTu` | Có | ✅ |
| B2 | Bảng `Kho` | Có | ✅ |
| B3 | Bảng `TonKho` | Có, là bảng được phân mảnh ngang | ✅ |
| B4 | Bảng `PhieuNhap` | Có + `ChiTietNhap` | ✅ |
| B5 | Bảng `PhieuXuat` | Có + `ChiTietXuat` | ✅ |
| B6 | Bảng `NhaCungCap` | Có | ✅ |
| B7 | **Nhập vật tư tại Kho A** | `sp_NhapKho` | ✅ đã chạy thật |
| B8 | **Xuất vật tư tại Kho B** | `sp_XuatKho` | ✅ đã chạy thật |
| B9 | **Kiểm tra tồn kho toàn hệ thống** | View `v_TonKho_ToanHeThong`, 24 dòng từ 3 máy | ✅ script `09` |
| B10 | **Điều chuyển vật tư giữa 2 kho** | `sp_DieuChuyenVatTu` | ✅ script `07` đã chạy thật |
| B11 | **Đồng bộ danh mục vật tư** | Publication `PUB_DanhMuc` | ✅ script `06`, `06b` |
| B12 | **DEMO: Kho A chuyển 50 → Kho B** | Kịch bản T1 | ✅ có ảnh 800→750 / 150→200 |
| B13 | **DEMO: thất bại giữa chừng → nhất quán** | Kịch bản T2, T3 (rollback 2PC) | ✅ có ảnh rollback |

---

## C. NỘI DUNG CUỐN BÁO CÁO

### 1. Các đề tài được giao

| Mục | Nội dung | Trạng thái |
|---|---|---|
| 1 | Ghi rõ đề tài 2, căn cứ file Excel phân công | ❗ cần số nhóm + xác nhận |

### 2.1. Đặt vấn đề

| Mục | Nội dung | Nguồn | Trạng thái |
|---|---|---|---|
| 2.1a | Nhu cầu và tầm quan trọng của dự án | viết mới | ⬜ |
| 2.1b | Sơ lược dự án, nhiệm vụ chính | viết mới | ⬜ |
| 2.1c | **Làm nổi bật vì sao BẮT BUỘC dùng CSDLPT** | dựa vào bảng tần suất §3.2 thiết kế | ⬜ |
| 2.1d | Vị trí và nhiệm vụ từng site | `00_ThietKe_HeThong.md` §1 | ⬜ |
| 2.1e | Dữ liệu khi triển khai | `00_ThietKe_HeThong.md` §2, §6 | ⬜ |
| 2.1f | Các đối tượng tham gia sử dụng | `00_ThietKe_HeThong.md` §3.3 | ⬜ |

### 2.2.1. Phân tích

| Mục | Nội dung | Nguồn | Trạng thái |
|---|---|---|---|
| a | Các chức năng chính truy cập dữ liệu | thiết kế §3.1 (F1–F7) | ✅ |
| b | **Bảng tần suất truy cập tại các vị trí** | thiết kế §3.2 | ✅ |
| c | **Phân quyền cho các nhóm đối tượng** | thiết kế §3.3 + script `10` (4 vai trò) | ✅ **đã cài đặt cả 3 site** |
| d | **Phân tích chức năng của từng vị trí** *(mục đỏ trong đề cương)* | thiết kế §3.1 + §1.1 | ✅ |
| e | Chức năng ở máy trạm, máy chủ | thiết kế **§3.4** — 2 bảng + sơ đồ ranh giới | ✅ |
| f | Phân tích CSDL — **mô hình thực thể liên kết (ERD)** | thiết kế **§2.4** — thực thể, 3 mối M:N, bản số, 7 ràng buộc | ✅ |

### 2.2.2. Thiết kế

| Mục | Nội dung | Nguồn | Trạng thái |
|---|---|---|---|
| a1 | Tên bảng, cấu trúc các bảng | thiết kế §2.2, §2.3 | ✅ |
| a2 | **Diagram quan hệ giữa các bảng** | thiết kế **§2.5** — 10 khóa ngoại + cách xuất từ SSMS | ✅ tài liệu, ⬜ chờ chụp ảnh |
| a3 | Lược đồ phục vụ **phân mảnh ngang** | thiết kế §4.1 | ✅ |
| a4 | Lược đồ phục vụ **phân mảnh ngang dẫn xuất** | thiết kế §4.2 | ✅ |
| a5 | Lược đồ phục vụ **nhân bản** | thiết kế §5 | ✅ |
| a6 | **Lược đồ ánh xạ** *(mục đỏ)* | thiết kế §10 — 4 tầng | ✅ |
| a7 | **Thiết kế định vị + vẽ sơ đồ định vị** | thiết kế §9 bảng + **§9.1 sơ đồ** + căn cứ định vị | ✅ |
| a8 | **Đồng bộ hóa** | thiết kế §5 | ✅ |
| a9 | **Thiết kế kiến trúc hệ thống** | thiết kế §1.2 | ✅ |
| b1 | QTLPT: **Ngang hàng hay Client/Server** | thiết kế §1.2 — lai hai kiểu, có giải thích | ✅ |
| b2 | QTLPT: **Đường đồng bộ hóa, LinkServer** | thiết kế §1.1 sơ đồ + §8 | ✅ |
| b3 | **Mô hình hệ thống tại chi nhánh và toàn hệ thống (front end / back end)** | thiết kế **§9.2** — 2 sơ đồ + bảng 3 tầng | ✅ |

### 3. Cài đặt vật lý thực tế

| Mục | Nội dung | Ảnh cần | Trạng thái |
|---|---|---|---|
| 3.1 | **Cài đặt VPN** — ZeroTier | 4 ảnh | 🔄 có `HUONG_DAN_ZEROTIER_3MAY.md` — chờ bạn cài |
| 3.2 | **Tạo đường link kết nối mạng giữa các server** | 7 ảnh | 🔄 có `BatTCPIP_VaFirewall.ps1` — chờ chạy Admin |
| 3.3 | **Cài đặt SQL Server** + print screen từng màn hình | ~16 ảnh | ✅ 18 ảnh (thư mục `ảnh` + `99_SSMS_3Instance`) |
| 3.4 | **Kiểm tra dịch vụ Agent** | 2 ảnh | 🔄 đã xem qua: 7/7 service Running+Automatic — ⬜ chờ lưu ảnh vào thư mục |
| 3.5 | **Tạo link CSDL giữa các Server** + print screen | 4 ảnh | ✅ đủ 4 ảnh |
| 3.6 | **Tạo Publication** + print screen | 7 ảnh | ✅ 4 ảnh cốt lõi (đủ minh chứng) |
| 3.7a | Thử giao tác — **Nhập dữ liệu** | 2 ảnh | ✅ script `04` đã chạy |
| 3.7b | **Hiển thị dữ liệu** (kiểm tra đồng bộ / nhân bản / phân mảnh / linkserver) | 4 ảnh | ✅ script `09` PHẦN 2,5,6,7 — ⬜ chờ chụp |
| 3.7c | **Thống kê** (kiểm tra đồng bộ / nhân bản / phân mảnh / linkserver) | 3 ảnh | ✅ script `09` PHẦN 3,4,8 — ⬜ chờ chụp |
| 3.7d | **Viết trigger phân quyền bảo vệ các bảng** | 3 ảnh | ✅ script `10` — 6 trigger, 3 site — ⬜ chờ chụp |
| 3.7e | Thử các transaction | 6 ảnh | ✅ **7 ảnh** T1/T2/T3 Results + Messages |
| Bonus | Phần mềm ứng dụng cho các trạm | — | ⬜ tùy thời gian |

---

## D. NHỮNG THỨ CẦN BẠN CUNG CẤP

| # | Nội dung | Dùng cho | Trạng thái |
|---|---|---|---|
| D1 | **Danh sách 5 thành viên** (họ tên + MSSV) | Trang bìa báo cáo | ❗ |
| D2 | **Số nhóm** và xác nhận được giao đề tài 2 | Mục 1 | ❗ |
| D3 | **Các lệnh SQL giảng viên gửi** (đề cương mục 3.3 có nhắc) | Đối chiếu cách làm | ❗ |
| D4 | **Tài liệu hướng dẫn tạo Publication của giảng viên** (mục 3.6) | Làm đúng khuôn thầy dạy | ❗ |
| D5 | Hạn nộp + định dạng nộp (Word/PDF, in giấy?) | Lên kế hoạch | ❗ |
| D6 | 3 site chạy trên 1 máy hay 3 máy thật qua ZeroTier? | Quyết định mục 3.1, 3.2 | ✅ **ĐÃ CHỐT**: 3 instance trên máy bạn + ZeroTier; hôm lên lớp rủ 2 bạn join mạng ảo để có ảnh 3 máy thật |
| D7 | Mẫu báo cáo `Mau Cuon Bao Cao Do An Mon Hoc 2025.docx` | Khuôn trình bày | ✅ đã có trên máy |

---

## E. TIẾN ĐỘ TỔNG THỂ

```
Cài đặt 3 instance      ████████████████████  100%   KHO_A/B/C đều Running, Developer Ed.
Thiết kế hệ thống       ████████████████████  100%   00_ThietKe_HeThong.md (đủ ERD, diagram, định vị, FE/BE)
Script tạo CSDL         ████████████████████  100%   01, 02, 03   ĐÃ CHẠY THẬT cả 3 site
Thủ tục nghiệp vụ       ████████████████████  100%   04           ĐÃ CHẠY THẬT cả 3 site
Linked Server (3.5)     ████████████████████  100%   05           6/6 link THÔNG
Replication   (3.6)     ████████████████████  100%   06, 06b      ĐỒNG BỘ CHẠY THẬT
Giao tác phân tán 2PC   ████████████████████  100%   07   T1/T2/T3 ĐỀU ĐÚNG
Concurrency             ████████████████████  100%   08   C1/C2/C3/C4 ĐỀU ĐÚNG
Distributed query       ████████████████████  100%   09   9 PHẦN, exit code 0
Trigger + phân quyền    ████████████████████  100%   10   6 trigger + 4 vai trò, 3 site OK
Chụp ảnh minh chứng     ████████████████░░░░   80%   34 ảnh — thiếu 3.1, 3.2, 3.4, diagram
Viết báo cáo            ░░░░░░░░░░░░░░░░░░░░    0%   làm sau cùng
```

### Mốc đã đạt (cập nhật 12/09/2026)

| Thời điểm | Kết quả |
|---|---|
| Cài đặt | 3 instance `KHO_A`, `KHO_B`, `KHO_C` — Developer Edition, Agent + Browser `Automatic` |
| Script `01`–`03` | 3 database, mỗi site chỉ chứa **đúng 1 mã kho** → phân mảnh ngang hoạt động |
| Script `04` | Nhập/xuất kho chạy thật; xuất quá tồn bị chặn đúng |
| Script `05` | **6/6 Linked Server thông**, truy vấn phân tán 3 site cho kết quả nhất quán |
| Dữ liệu | KHO_B thiếu `VT009` đúng 50 đơn vị → đúng kịch bản điều chuyển của đề bài |

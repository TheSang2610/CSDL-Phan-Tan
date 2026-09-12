# DANH SÁCH ẢNH CẦN CHỤP CHO BÁO CÁO

Chụp nhanh bằng **`Windows + Shift + S`**, dán vào Paint rồi lưu, hoặc dán thẳng vào Word.
Đặt tên file theo số thứ tự để khỏi lẫn, ví dụ `01_Edition.png`, `02_FeatureSelection.png`.

---

## 3.3 — Cài đặt SQL Server  → thư mục `3.3_CaiDat_SQLServer/`

Chụp trong lúc cài **KHO_B** (KHO_A đã cài trước nên bỏ qua, KHO_C chụp bổ sung 2 ảnh cuối).

| # | Màn hình | Lý do cần có |
|---|---|---|
| 01 | Edition | Chứng minh dùng bản hợp lệ (Developer/Evaluation) |
| 02 | Feature Selection | **Quan trọng nhất** — thấy rõ đã tick `SQL Server Replication` |
| 03 | Instance Configuration | Thấy tên instance `KHO_B` và đường dẫn ổ D |
| 04 | Server Configuration | Thấy `SQL Server Agent` = **Automatic** |
| 05 | Database Engine Configuration | Thấy **Mixed Mode** và tài khoản sysadmin |
| 06 | Ready to Install | Bảng tổng hợp toàn bộ lựa chọn |
| 07 | Complete | Báo cài thành công |
| 08 | SSMS — Object Explorer | Kết nối được cả 3 instance `MIGNON\KHO_A`, `\KHO_B`, `\KHO_C` |

## 3.4 — Dịch vụ Agent  → `3.4_DichVu_Agent/`

| # | Màn hình |
|---|---|
| 01 | SQL Server Configuration Manager — thấy 3 dịch vụ `SQL Server Agent (KHO_A/B/C)` đang **Running** |
| 02 | SSMS — nút **SQL Server Agent** trong Object Explorer có dấu hiệu đang chạy (không có dấu X đỏ) |

## 3.5 — Linked Server  → `3.5_LinkedServer/`

| # | Màn hình |
|---|---|
| 01 | SSMS → Server Objects → Linked Servers — thấy đủ các liên kết giữa 3 site |
| 02 | Hộp thoại New Linked Server, tab **General** |
| 03 | Hộp thoại New Linked Server, tab **Security** |
| 04 | Kết quả chạy `SELECT * FROM [MIGNON\KHO_B].KhoB.dbo.TonKho` — lấy được dữ liệu site khác |

## 3.6 — Publication / Replication  → `3.6_Publication_Replication/`

| # | Màn hình |
|---|---|
| 01 | Configure Distribution Wizard |
| 02 | New Publication Wizard — trang chọn **Publication Type** (Transactional) |
| 03 | Trang chọn **Articles** — thấy 3 bảng `VatTu`, `NhaCungCap`, `Kho` |
| 04 | Trang đặt tên publication `PUB_DanhMuc` |
| 05 | New Subscription Wizard — chọn subscriber `KHO_B`, `KHO_C` |
| 06 | Replication Monitor — trạng thái đồng bộ màu xanh |
| 07 | **Bằng chứng đồng bộ**: sửa 1 dòng `VatTu` ở KHO_A → query ở KHO_B thấy đổi theo |

## 3.7 — Kết quả giao tác  → `3.7_KetQua_GiaoTac/`

| # | Nội dung | Script |
|---|---|---|
| 01 | Kết quả chạy `01_TaoCSDL_KhoA.sql` — bảng đếm số dòng từng bảng | `01` |
| 02 | **Bằng chứng phân mảnh**: chèn sai kho bị `CHECK` chặn | `01` |
| 03 | Nhập kho thành công + xuất kho thành công | `04` |
| 04 | Xuất quá tồn → bị chặn, rollback | `04` |
| 05 | **Điều chuyển 50 sản phẩm KHO_A → KHO_B thành công** | `06` |
| 06 | **Điều chuyển thất bại giữa chừng → rollback cả 2 site** | `06` |
| 07 | Tình huống tương tranh: 2 phiên cùng xuất, lost update | `07` |
| 08 | Deadlock và cách xử lý | `07` |
| 09 | Truy vấn tồn kho toàn hệ thống qua 3 site | `08` |
| 10 | So sánh Linked Server vs `OPENQUERY` (`STATISTICS IO/TIME`) | `08` |

---

## Mẹo

- Chụp **cả cửa sổ** chứ đừng cắt sát nội dung — có thanh tiêu đề thì người chấm biết đang ở instance nào.
- Với kết quả SQL, chụp **cả câu lệnh lẫn kết quả** trong một ảnh.
- Ảnh quan trọng nhất, thầy chắc chắn xem: **02** ở mục 3.3 (đã tick Replication), **07** ở mục 3.6 (bằng chứng đồng bộ), **05 và 06** ở mục 3.7 (điều chuyển thành công và rollback).

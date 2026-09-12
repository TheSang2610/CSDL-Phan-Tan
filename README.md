# CSDL Phân Tán — Bài tập và Đồ án cuối kỳ

Kho mã nguồn môn **Cơ sở dữ liệu phân tán**.

---

## 📁 Cấu trúc

| Thư mục | Nội dung |
|---|---|
| `Do an cuoi ki/` | **Đồ án cuối kỳ** — Quản lý kho vật tư đa chi nhánh (3 site) |
| `BT01_Nhom02/` | Bài tập 1 — Phân mảnh ngang, quản lý sinh viên |
| `BT02_Nhom02/` | Bài tập 2 — Phân mảnh ngang nguyên thủy + dẫn xuất, bán hàng |
| `ảnh/` | Ảnh chụp quá trình cài đặt 3 instance SQL Server |

---

# ĐỒ ÁN CUỐI KỲ — QUẢN LÝ KHO VẬT TƯ ĐA CHI NHÁNH

## Kiến trúc

Ba site độc lập, mỗi site một instance SQL Server 2022 Developer Edition:

| Site | Instance | Database | Cổng | Vai trò |
|---|---|---|---|---|
| S1 | `MIGNON\KHO_A` | `KhoA` | 1440 | Kho Trung tâm — **Publisher + Distributor** |
| S2 | `MIGNON\KHO_B` | `KhoB` | 1441 | Kho Miền Bắc — Subscriber |
| S3 | `MIGNON\KHO_C` | `KhoC` | 1442 | Kho Miền Nam — Subscriber |

**Phân mảnh ngang nguyên thủy** — `TonKho`, `PhieuNhap`, `PhieuXuat` cắt theo `MaKho`, cưỡng chế bằng `CHECK (MaKho = 'KHO_x')`.

**Phân mảnh ngang dẫn xuất** — `ChiTietNhap = ChiTietNhap ⋉ PhieuNhap_i`, `ChiTietXuat = ChiTietXuat ⋉ PhieuXuat_i`.

**Nhân bản** — Transactional Replication đẩy `VatTu`, `NhaCungCap`, `Kho` từ KHO_A xuống hai site kia.

**Giao tác phân tán** — `sp_DieuChuyenVatTu` dùng `BEGIN DISTRIBUTED TRANSACTION` qua MS DTC (2PC).

---

## ▶️ Thứ tự chạy script

Toàn bộ nằm trong `Do an cuoi ki/SQL/`.

| # | File | Chạy ở đâu | Ghi chú |
|---|---|---|---|
| 1 | `01_TaoCSDL_KhoA.sql` | `MIGNON\KHO_A` | Tạo DB + 9 bảng + dữ liệu mẫu |
| 2 | `02_TaoCSDL_KhoB.sql` | `MIGNON\KHO_B` | |
| 3 | `03_TaoCSDL_KhoC.sql` | `MIGNON\KHO_C` | |
| 4 | `04_ThuTuc_NghiepVu.sql` | **cả 3 site** | Nhập / xuất / tra cứu — chạy y nguyên, không sửa |
| 5 | `05_LinkedServer.sql` | **cả 3 site** | Tạo 6 Linked Server (mỗi site 2) |
| 6 | `06_Replication_DongBoDanhMuc.sql` | `MIGNON\KHO_A` | Publication `PUB_DanhMuc` + 2 push subscription |
| 7 | `06b_Demo_DongBoDanhMuc.sql` | `MIGNON\KHO_A` | Kiểm chứng đồng bộ (chờ ~20 giây) |
| 8 | `07_DieuChuyen_GiaoTacPhanTan.sql` | PHẦN 1 ở **cả 3 site**, phần còn lại ở `KHO_A` | 2PC — T1/T2/T3 |
| 9 | `08_TuongTranh_Concurrency.sql` | `MIGNON\KHO_B` | **Cần 2 cửa sổ query** — C1/C2/C3/C4 |
| 10 | `09_TruyVanPhanTan_ThongKe.sql` | `MIGNON\KHO_A` | Truy vấn phân tán + kiểm tra phân mảnh/nhân bản |
| 11 | `10_PhanQuyen_Trigger.sql` | **cả 3 site** | 6 trigger + 4 vai trò |

> ⚠️ File `08` chạy khác các file kia: phải mở **hai cửa sổ query** đặt cạnh nhau
> (chuột phải tab → *New Vertical Tab Group*) vì nó mô phỏng hai người dùng
> thao tác cùng lúc. Hướng dẫn chi tiết nằm ở đầu file.

---

## ✅ Nội dung đã kiểm chứng bằng chạy thật

| Chủ đề | Kết quả |
|---|---|
| Phân mảnh | Mỗi site đúng 1 `MaKho`; 10 + 7 + 7 = **24 = 24** dòng toàn cục |
| Tách rời | **0** dòng trùng giữa các mảnh |
| Ghi sai mảnh | Bị chặn bằng lỗi **547** `CK_TonKho_Manh` |
| Nhân bản | 3 site cùng vân tay `CHECKSUM_AGG` = **347490305** |
| Đồng bộ | Sửa ở KHO_A → KHO_B và KHO_C nhận sau ~15–20 giây |
| 2PC thành công | KHO_A 800→750, KHO_B 150→200, phiếu `DCA001` ghi ở **cả hai site** |
| 2PC thất bại giữa chừng | Rollback sạch — tồn kho và số phiếu **y nguyên ở cả hai site** |
| Lost update | Không khóa → mất đúng **100** đơn vị |
| Khóa bi quan | `UPDLOCK, HOLDLOCK` → phiên sau chờ 13 giây, kết quả **đúng** |
| Khóa lạc quan | `ROWVERSION` → phiên thua bị từ chối, không ghi đè |
| Deadlock | SQL Server chọn nạn nhân, **Msg 1205**, dữ liệu vẫn nhất quán |
| Trigger | Chặn cả `sa`: xoá chứng từ đã hoàn tất và sửa bản sao nhân bản |

---

## 📄 Tài liệu

| File | Nội dung |
|---|---|
| `Do an cuoi ki/00_ThietKe_HeThong.md` | Thiết kế 13 mục: tần suất truy cập, phân mảnh, lược đồ ánh xạ, định vị |
| `Do an cuoi ki/00_CHECKLIST_YEU_CAU.md` | Đối chiếu từng mục đề cương với việc đã làm |
| `Do an cuoi ki/HUONG_DAN_CAI_DAT_3_INSTANCE.md` | Cài 3 instance từ đầu |
| `Do an cuoi ki/HUONG_DAN_ZEROTIER_3MAY.md` | Mục 3.1 VPN + 3.2 link mạng giữa các server |
| `Do an cuoi ki/HUONG_DAN_SSMS_VA_CHUP_ANH.md` | Kết nối SSMS và chụp ảnh minh chứng |
| `Do an cuoi ki/AnhChup/` | Ảnh minh chứng theo từng mục báo cáo |

---

## ⚙️ Yêu cầu môi trường

- SQL Server 2022 Developer Edition — 3 named instance
- SQL Server Management Studio
- **SQL Server Agent** phải `Running` ở cả 3 instance (replication cần)
- **SQL Server Browser** phải `Running`
- **MS DTC** phải `Running` (giao tác phân tán cần)

Nếu tên máy không phải `MIGNON`, tìm và thay `Mignon\` trong các script `05`–`10`
bằng tên máy của bạn, đồng thời cập nhật cột `ServerName` trong bảng `Kho`.

> ⚠️ **Về cấu hình bảo mật của đồ án.** Các script `05`, `06`, `11` ghi thẳng mật
> khẩu tài khoản `sa` của môi trường phòng thực hành. Đó là mật khẩu đặt cố ý cho
> lab, không dùng lại ở bất kỳ máy nào khác. Cấu hình MS DTC cũng đặt
> **No Authentication Required** vì ba máy không nằm trong domain — môi trường
> thật phải dùng **Mutual Authentication**.
>
> Ba máy của nhóm chỉ nối với nhau qua mạng ảo ZeroTier, không mở cổng ra
> Internet. Sau buổi bảo vệ nên đổi mật khẩu `sa` hoặc gỡ ba instance đi.

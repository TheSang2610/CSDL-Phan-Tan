# ĐỒ ÁN CUỐI KỲ — QUẢN LÝ KHO VẬT TƯ ĐA CHI NHÁNH
## Tài liệu thiết kế hệ thống CSDL phân tán

> **Đề tài 2** — Quản lý kho vật tư đa chi nhánh. 3 site: Kho A, Kho B, Kho C.
> Nền tảng: **SQL Server 2022** (3 instance trên máy `MIGNON`) + SSMS 19.
> Tài liệu này là phần **thiết kế**; phần cài đặt nằm trong thư mục `SQL/`.

---

## 1. Kiến trúc hệ thống

### 1.1. Ba site

| Site | Instance | Database | Vai trò nghiệp vụ | Vai trò phân tán |
|---|---|---|---|---|
| **S1** | `MIGNON\KHO_A` | `KhoA` | **Kho Trung tâm** (Hà Nội) | **Publisher** — chủ danh mục, điều phối |
| **S2** | `MIGNON\KHO_B` | `KhoB` | **Kho Miền Bắc** (Bắc Ninh) | Subscriber |
| **S3** | `MIGNON\KHO_C` | `KhoC` | **Kho Miền Nam** (TP. Hồ Chí Minh) | Subscriber |

### 1.2. Kiểu kiến trúc

**Lai giữa Client/Server và Ngang hàng (hybrid):**

- **Ngang hàng (peer-to-peer)** với dữ liệu **tồn kho và chứng từ**: mỗi kho toàn quyền trên mảnh dữ liệu của mình, không kho nào phụ thuộc kho khác để nhập/xuất hàng ngày. Ba site nối với nhau bằng **Linked Server** hai chiều.
- **Client/Server** với dữ liệu **danh mục** (`VatTu`, `NhaCungCap`, `Kho`): Kho Trung tâm là **Publisher** duy nhất được sửa; hai kho còn lại là **Subscriber** chỉ đọc. Bảo đảm danh mục vật tư toàn hệ thống luôn thống nhất.

```
                       ┌──────────────────────────────┐
                       │   S1 — MIGNON\KHO_A          │
                       │   Kho Trung tâm (Hà Nội)     │
                       │   PUBLISHER + DISTRIBUTOR    │
                       └───────┬──────────────┬───────┘
             Replication       │              │      Replication
             (danh mục)        │              │      (danh mục)
                  ┌────────────┘              └────────────┐
                  ▼                                        ▼
    ┌──────────────────────────┐              ┌──────────────────────────┐
    │  S2 — MIGNON\KHO_B       │              │  S3 — MIGNON\KHO_C       │
    │  Kho Miền Bắc            │              │  Kho Miền Nam            │
    │  SUBSCRIBER              │              │  SUBSCRIBER              │
    └──────────┬───────────────┘              └───────────┬──────────────┘
               │                                          │
               └──────────── Linked Server ───────────────┘
                    (truy vấn phân tán + giao tác phân tán qua MS DTC)
```

---

## 2. Lược đồ CSDL toàn cục

### 2.1. Danh sách bảng

| # | Bảng | Ý nghĩa | Nhóm |
|---|---|---|---|
| 1 | `NhaCungCap` | Nhà cung cấp vật tư | **Danh mục** (nhân bản) |
| 2 | `VatTu` | Danh mục vật tư | **Danh mục** (nhân bản) |
| 3 | `Kho` | Danh sách 3 kho | **Danh mục** (nhân bản) |
| 4 | `TonKho` | Số lượng tồn của từng vật tư tại từng kho | **Phân mảnh ngang nguyên thủy** |
| 5 | `PhieuNhap` | Phiếu nhập kho | **Phân mảnh ngang dẫn xuất** |
| 6 | `ChiTietNhap` | Chi tiết dòng hàng của phiếu nhập | **Phân mảnh ngang dẫn xuất** |
| 7 | `PhieuXuat` | Phiếu xuất kho | **Phân mảnh ngang dẫn xuất** |
| 8 | `ChiTietXuat` | Chi tiết dòng hàng của phiếu xuất | **Phân mảnh ngang dẫn xuất** |
| 9 | `PhieuDieuChuyen` | Phiếu điều chuyển vật tư giữa 2 kho | **Nhân bản một phần** (2 kho liên quan) |

### 2.2. Cấu trúc chi tiết

```
NhaCungCap ( MaNCC , TenNCC , DiaChi , DienThoai , Email )
             ─────                                          PK: MaNCC

VatTu      ( MaVT , TenVT , DonViTinh , DonGia , MaNCC , MucTonToiThieu )
             ────                                           PK: MaVT
                                                            FK: MaNCC → NhaCungCap

Kho        ( MaKho , TenKho , DiaChi , ServerName )
             ─────                                          PK: MaKho
                                                            ServerName: tên instance để build Linked Server

TonKho     ( MaKho , MaVT , SoLuong , NgayCapNhat , RowVer )
             ────────────                                   PK: (MaKho, MaVT)
                                                            FK: MaKho → Kho, MaVT → VatTu
                                                            RowVer: rowversion — chống lost update

PhieuNhap  ( MaPN , MaKho , MaNCC , NgayNhap , NguoiLap , TrangThai )
             ────                                           PK: MaPN
                                                            FK: MaKho → Kho, MaNCC → NhaCungCap

ChiTietNhap( MaPN , MaVT , SoLuong , DonGia )
             ───────────                                    PK: (MaPN, MaVT)
                                                            FK: MaPN → PhieuNhap, MaVT → VatTu

PhieuXuat  ( MaPX , MaKho , NgayXuat , NguoiNhan , NguoiLap , TrangThai )
             ────                                           PK: MaPX
                                                            FK: MaKho → Kho

ChiTietXuat( MaPX , MaVT , SoLuong , DonGia )
             ───────────                                    PK: (MaPX, MaVT)
                                                            FK: MaPX → PhieuXuat, MaVT → VatTu

PhieuDieuChuyen ( MaDC , MaKhoNguon , MaKhoDich , MaVT , SoLuong ,
                  NgayLap , TrangThai , GhiChu )
                  ────                                      PK: MaDC
                  TrangThai: CHO_DUYET | HOAN_TAT | THAT_BAI | DA_HUY
```

### 2.3. Quy ước mã

| Bảng | Quy ước | Ví dụ |
|---|---|---|
| `Kho` | `KHO_A`, `KHO_B`, `KHO_C` | |
| `VatTu` | `VT` + 3 số | `VT001` |
| `NhaCungCap` | `NCC` + 2 số | `NCC01` |
| `PhieuNhap` | `PN` + mã kho + số thứ tự | `PNA0001` |
| `PhieuXuat` | `PX` + mã kho + số thứ tự | `PXB0001` |
| `PhieuDieuChuyen` | `DC` + số thứ tự | `DC0001` |

> Mã chứng từ **có nhúng ký tự kho** (`PNA`, `PNB`, `PNC`) để bảo đảm **khóa chính không đụng nhau giữa 3 site** — đây là kỹ thuật bắt buộc khi khóa chính được sinh độc lập ở nhiều nơi trong hệ phân tán.

---

## 3. Phân tích chức năng và tần suất truy cập

### 3.1. Các chức năng chính

| Mã | Chức năng | Site thực hiện | Bảng truy cập | Kiểu |
|---|---|---|---|---|
| F1 | Nhập vật tư vào kho | Kho sở tại | `PhieuNhap`, `ChiTietNhap`, `TonKho` | Ghi, cục bộ |
| F2 | Xuất vật tư khỏi kho | Kho sở tại | `PhieuXuat`, `ChiTietXuat`, `TonKho` | Ghi, cục bộ |
| F3 | Tra cứu tồn kho tại chỗ | Kho sở tại | `TonKho`, `VatTu` | Đọc, cục bộ |
| F4 | **Kiểm tra tồn kho toàn hệ thống** | Kho Trung tâm | `TonKho` ở **cả 3 site** | Đọc, **phân tán** |
| F5 | **Điều chuyển vật tư giữa 2 kho** | Kho nguồn | `TonKho` ở **2 site**, `PhieuDieuChuyen` | Ghi, **giao tác phân tán** |
| F6 | Thêm/sửa danh mục vật tư | **Chỉ Kho Trung tâm** | `VatTu`, `NhaCungCap` | Ghi, **nhân bản xuống 2 site** |
| F7 | Cảnh báo vật tư dưới mức tồn tối thiểu | Mọi site | `TonKho`, `VatTu` | Đọc, cục bộ |

### 3.2. Bảng tần suất truy cập (lần/ngày)

| Chức năng | Kho A (Trung tâm) | Kho B (Bắc) | Kho C (Nam) | Tổng |
|---|---:|---:|---:|---:|
| F1 — Nhập kho | 40 | 25 | 30 | 95 |
| F2 — Xuất kho | 60 | 45 | 55 | 160 |
| F3 — Tra cứu tồn tại chỗ | 120 | 90 | 100 | 310 |
| F4 — Tồn kho toàn hệ thống | 15 | 2 | 2 | 19 |
| F5 — Điều chuyển | 8 | 5 | 5 | 18 |
| F6 — Sửa danh mục | 6 | 0 | 0 | 6 |
| F7 — Cảnh báo tồn tối thiểu | 10 | 8 | 8 | 26 |

**Nhận xét dẫn tới thiết kế phân mảnh:**

1. F1, F2, F3 chiếm **565/634 ≈ 89%** tổng lượt truy cập và **hoàn toàn cục bộ theo kho** ⟹ phải **phân mảnh ngang `TonKho` và chứng từ theo `MaKho`** để 89% nghiệp vụ chạy tại chỗ, không qua mạng.
2. F6 chỉ xảy ra ở Kho Trung tâm (6 lần/ngày) nhưng **mọi site đều cần đọc danh mục** ⟹ **nhân bản** `VatTu`, `NhaCungCap`, `Kho` thay vì phân mảnh (tỷ lệ đọc/ghi rất cao — điều kiện lý tưởng để nhân bản).
3. F4 và F5 là hai nghiệp vụ **bắt buộc vượt site** ⟹ cần **truy vấn phân tán** và **giao tác phân tán**.

### 3.3. Phân quyền

| Nhóm người dùng | Site | Quyền |
|---|---|---|
| `NhanVienKho` | Kho sở tại | `SELECT`, `INSERT` trên chứng từ và `TonKho` của **kho mình**; `SELECT` danh mục |
| `TruongKho` | Kho sở tại | Quyền của `NhanVienKho` + `UPDATE`, `EXECUTE` thủ tục điều chuyển |
| `QuanTriDanhMuc` | Chỉ Kho Trung tâm | Toàn quyền trên `VatTu`, `NhaCungCap` (nguồn nhân bản) |
| `BanGiamDoc` | Kho Trung tâm | `SELECT` toàn hệ thống qua Linked Server (F4) |

Ràng buộc "chỉ thao tác trên kho của mình" được cưỡng chế bằng **CHECK constraint** + **trigger** tại mỗi site (xem `SQL/09_PhanQuyen_Trigger.sql`).

---

## 4. Thiết kế phân mảnh

### 4.1. Phân mảnh ngang NGUYÊN THỦY — bảng `TonKho`

Vị từ đơn giản sinh từ F1/F2/F3 (mỗi kho chỉ thao tác trên tồn của mình):

```
p1: MaKho = 'KHO_A'      p2: MaKho = 'KHO_B'      p3: MaKho = 'KHO_C'
```

Tập suy dẫn: `p1 ∨ p2 ∨ p3 ≡ TRUE` và đôi một loại trừ ⟹ COM_MIN giữ `Pr' = {p1, p2}`, `p3 ⇔ ¬p1 ∧ ¬p2`.

| Mảnh | Định nghĩa | Đặt tại |
|---|---|---|
| `TonKho_A` | σ(MaKho = 'KHO_A')(TonKho) | S1 |
| `TonKho_B` | σ(MaKho = 'KHO_B')(TonKho) | S2 |
| `TonKho_C` | σ(MaKho = 'KHO_C')(TonKho) | S3 |

### 4.2. Phân mảnh ngang DẪN XUẤT — chứng từ

`PhieuNhap` / `PhieuXuat` có thuộc tính `MaKho` nên về hình thức có thể phân mảnh nguyên thủy; nhưng `ChiTietNhap` / `ChiTietXuat` **không có** `MaKho` ⟹ bắt buộc phân mảnh **dẫn xuất** theo phiếu:

```
PhieuNhap_i  = σ(MaKho = 'KHO_i')(PhieuNhap)              (nguyên thủy)
ChiTietNhap_i = ChiTietNhap ⋉ PhieuNhap_i                 (DẪN XUẤT, nửa nối theo MaPN)

PhieuXuat_i  = σ(MaKho = 'KHO_i')(PhieuXuat)
ChiTietXuat_i = ChiTietXuat ⋉ PhieuXuat_i                 (DẪN XUẤT, nửa nối theo MaPX)
```

**Đồ thị nối:** `ChiTietNhap → PhieuNhap → Kho` — dạng cây, đơn giản, mỗi thành viên có đúng một chủ ⟹ đủ điều kiện phân mảnh dẫn xuất.

**Tính tách biệt** được bảo đảm vì `PhieuNhap : ChiTietNhap` là quan hệ **1:N** — mỗi dòng chi tiết thuộc đúng một phiếu, phiếu đó thuộc đúng một kho.

### 4.3. Kiểm tra ba tiêu chuẩn

| Tiêu chuẩn | `TonKho` | Chứng từ |
|---|---|---|
| **Đầy đủ** | `MaKho` NOT NULL + FK → `Kho`, miền chỉ 3 giá trị ⟹ mọi dòng thuộc đúng 1 mảnh | Toàn vẹn tham chiếu `ChiTietNhap.MaPN → PhieuNhap` bảo đảm không dòng nào mồ côi |
| **Tái thiết** | `TonKho = TonKho_A ∪ TonKho_B ∪ TonKho_C` | `ChiTietNhap = ∪ ChiTietNhap_i` |
| **Tách biệt** | Ba vị từ đôi một loại trừ | Liên kết 1:N ⟹ mỗi chi tiết đúng 1 mảnh |

---

## 5. Thiết kế nhân bản (Replication)

### 5.1. Phương pháp: Transactional Replication một chiều

| Thành phần | Cấu hình |
|---|---|
| **Publisher** | `MIGNON\KHO_A` (Kho Trung tâm) |
| **Distributor** | `MIGNON\KHO_A` (local distributor) |
| **Subscriber** | `MIGNON\KHO_B`, `MIGNON\KHO_C` |
| **Publication** | `PUB_DanhMuc` |
| **Article** | `NhaCungCap`, `VatTu`, `Kho` |
| **Kiểu Subscription** | **Push** (Distribution Agent chạy tại Publisher) |
| **Lịch chạy** | Continuous — đồng bộ gần như tức thời |

**Vì sao chọn Transactional mà không phải Merge:** danh mục vật tư chỉ được sửa ở **một nơi duy nhất** (Kho Trung tâm), hai site kia chỉ đọc ⟹ **không bao giờ có xung đột ghi** ⟹ Transactional là đủ, nhẹ hơn và độ trễ thấp hơn Merge. Merge chỉ cần khi nhiều site cùng được sửa một dòng.

> Đây chính là yêu cầu **"Đồng bộ danh mục vật tư"** của đề bài.

### 5.2. Nhân bản một phần — `PhieuDieuChuyen`

Phiếu điều chuyển liên quan **2 kho**, nên được ghi vào **cả hai site** trong cùng một giao tác phân tán (xem mục 6), không dùng replication. Lý do: cần **nhất quán tức thời**, không chấp nhận độ trễ.

---

## 6. Giao tác phân tán — Điều chuyển vật tư

### 6.1. Kịch bản bắt buộc của đề bài

> "Kho A chuyển 50 sản phẩm → Kho B. Nếu giao dịch thất bại giữa chừng thì dữ liệu phải được xử lý nhất quán."

### 6.2. Cơ chế: `BEGIN DISTRIBUTED TRANSACTION` + MS DTC

```
  Kho A (nguồn)                                     Kho B (đích)
  ────────────────                                  ────────────────
  BEGIN DISTRIBUTED TRANSACTION
     1. Kiểm tra TonKho_A.SoLuong >= 50
     2. TonKho_A.SoLuong -= 50
     3. INSERT PhieuDieuChuyen (CHO_DUYET)
                          ──── Linked Server ────►  4. TonKho_B.SoLuong += 50
                                                    5. INSERT PhieuDieuChuyen
     6. UPDATE TrangThai = 'HOAN_TAT'
  COMMIT   ←── MS DTC điều phối 2-Phase Commit ──►  COMMIT
```

**MS DTC làm gì:** đóng vai **Transaction Coordinator**, chạy giao thức **2PC**:
- **Pha 1 (Prepare):** hỏi cả hai site "sẵn sàng commit chưa?" — mỗi site ghi log và trả lời `YES`/`NO`.
- **Pha 2 (Commit/Abort):** nếu **mọi** site trả lời `YES` → ra lệnh commit đồng loạt; chỉ cần **một** site trả lời `NO` hoặc mất kết nối → **rollback toàn bộ ở cả hai nơi**.

⟹ Không bao giờ xảy ra tình trạng Kho A đã trừ 50 mà Kho B chưa cộng.

### 6.3. Bốn tình huống thất bại sẽ demo

| # | Tình huống | Kết quả mong đợi |
|---|---|---|
| T1 | Thành công bình thường | A giảm 50, B tăng 50, phiếu `HOAN_TAT` |
| T2 | Kho A **không đủ hàng** | `RAISERROR` → rollback, **cả hai kho không đổi** |
| T3 | Kho B **lỗi giữa chừng** (vật tư không tồn tại) | rollback, **A không bị trừ** |
| T4 | **Mất kết nối** tới Kho B sau khi A đã trừ | MS DTC abort → **A được hoàn lại** |

---

## 7. Tình huống tương tranh (Concurrency)

### 7.1. Kịch bản: hai nhân viên cùng xuất một vật tư

Tại Kho A, tồn `VT001` = 100. Hai phiên đồng thời:

| | Phiên 1 | Phiên 2 |
|---|---|---|
| t1 | Đọc SoLuong = 100 | |
| t2 | | Đọc SoLuong = 100 |
| t3 | Ghi 100 − 60 = 40 | |
| t4 | | Ghi 100 − 70 = 30 ❌ |

**Kết quả sai:** xuất tổng 130 nhưng tồn chỉ còn 30 thay vì âm/bị chặn — đây là lỗi **Lost Update**.

### 7.2. Hai cách khắc phục sẽ demo

**Cách 1 — Khóa bi quan (pessimistic):** đọc kèm `UPDLOCK, HOLDLOCK` trong `SERIALIZABLE`:

```sql
SELECT @Ton = SoLuong FROM TonKho WITH (UPDLOCK, HOLDLOCK)
WHERE MaKho = 'KHO_A' AND MaVT = 'VT001';
```

Phiên 2 bị **chặn** cho tới khi phiên 1 commit, sau đó đọc lại giá trị 40 và phát hiện không đủ hàng ⟹ từ chối đúng.

**Cách 2 — Khóa lạc quan (optimistic):** dùng cột `RowVer rowversion`:

```sql
UPDATE TonKho SET SoLuong = SoLuong - @SL
WHERE MaKho = @Kho AND MaVT = @VT AND RowVer = @RowVerDaDoc;
IF @@ROWCOUNT = 0  -- ai đó đã sửa trước → thử lại
```

Sẽ demo thêm **deadlock** giữa hai phiên điều chuyển ngược chiều (A→B và B→A cùng lúc) và cách chống bằng **thứ tự khóa nhất quán** (luôn khóa kho có mã nhỏ hơn trước).

---

## 8. Truy vấn phân tán (Distributed Query)

### 8.1. Kiểm tra tồn kho toàn hệ thống (F4)

```sql
SELECT vt.MaVT, vt.TenVT,
       SUM(CASE WHEN t.MaKho = 'KHO_A' THEN t.SoLuong ELSE 0 END) AS TonKhoA,
       SUM(CASE WHEN t.MaKho = 'KHO_B' THEN t.SoLuong ELSE 0 END) AS TonKhoB,
       SUM(CASE WHEN t.MaKho = 'KHO_C' THEN t.SoLuong ELSE 0 END) AS TonKhoC,
       SUM(t.SoLuong) AS TongToanHeThong
FROM (
        SELECT MaKho, MaVT, SoLuong FROM TonKho                              -- cục bộ
  UNION ALL
        SELECT MaKho, MaVT, SoLuong FROM [MIGNON\KHO_B].KhoB.dbo.TonKho      -- Linked Server
  UNION ALL
        SELECT MaKho, MaVT, SoLuong FROM [MIGNON\KHO_C].KhoC.dbo.TonKho      -- Linked Server
) t
JOIN VatTu vt ON vt.MaVT = t.MaVT
GROUP BY vt.MaVT, vt.TenVT;
```

### 8.2. Tối ưu: đẩy phép tính về site (predicate pushdown)

Sẽ so sánh hai cách và đo `STATISTICS IO/TIME`:

| Cách | Câu lệnh | Vấn đề |
|---|---|---|
| **Xấu** | `SELECT * FROM [KHO_B].KhoB.dbo.TonKho WHERE ...` | Kéo **toàn bộ** bảng về rồi mới lọc |
| **Tốt** | `SELECT * FROM OPENQUERY([KHO_B], 'SELECT ... WHERE ...')` | Lọc **tại site B**, chỉ truyền kết quả |

Đây là minh chứng cho nguyên lý **giảm chi phí truyền thông** — mục tiêu tối ưu chính của CSDL phân tán.

---

## 9. Lược đồ định vị (Allocation Schema)

| Bảng / Mảnh | S1 `KHO_A` | S2 `KHO_B` | S3 `KHO_C` | Cơ chế |
|---|:---:|:---:|:---:|---|
| `NhaCungCap` | **Gốc** | Bản sao | Bản sao | Replication |
| `VatTu` | **Gốc** | Bản sao | Bản sao | Replication |
| `Kho` | **Gốc** | Bản sao | Bản sao | Replication |
| `TonKho_A` | ✔ | — | — | Phân mảnh ngang |
| `TonKho_B` | — | ✔ | — | Phân mảnh ngang |
| `TonKho_C` | — | — | ✔ | Phân mảnh ngang |
| `PhieuNhap_A` + `ChiTietNhap_A` | ✔ | — | — | Nguyên thủy + dẫn xuất |
| `PhieuNhap_B` + `ChiTietNhap_B` | — | ✔ | — | |
| `PhieuNhap_C` + `ChiTietNhap_C` | — | — | ✔ | |
| `PhieuXuat_A` + `ChiTietXuat_A` | ✔ | — | — | |
| `PhieuXuat_B` + `ChiTietXuat_B` | — | ✔ | — | |
| `PhieuXuat_C` + `ChiTietXuat_C` | — | — | ✔ | |
| `PhieuDieuChuyen` | ✔ | ✔ | ✔ | Ghi 2 site qua giao tác phân tán |

**Ghi chú:** ba site dùng **cùng một tên bảng** `TonKho` (không đặt tên `TonKho_A`) — mảnh được xác định bởi **vị trí site** cộng với `CHECK (MaKho = 'KHO_A')`. Cách này giúp câu lệnh ứng dụng giống hệt nhau ở mọi site, đúng tinh thần **trong suốt phân mảnh (fragmentation transparency)**.

---

## 10. Lược đồ ánh xạ (Mapping Schema)

```
 TẦNG 1 — Lược đồ toàn cục (Global Schema)
     TonKho ( MaKho , MaVT , SoLuong , NgayCapNhat )
                     │
                     │  phân mảnh ngang theo MaKho
                     ▼
 TẦNG 2 — Lược đồ phân mảnh (Fragmentation Schema)
     TonKho_A = σ(MaKho='KHO_A')(TonKho)
     TonKho_B = σ(MaKho='KHO_B')(TonKho)
     TonKho_C = σ(MaKho='KHO_C')(TonKho)
                     │
                     │  định vị mảnh về site
                     ▼
 TẦNG 3 — Lược đồ định vị (Allocation Schema)
     TonKho_A → S1 (MIGNON\KHO_A , database KhoA)
     TonKho_B → S2 (MIGNON\KHO_B , database KhoB)
     TonKho_C → S3 (MIGNON\KHO_C , database KhoC)
                     │
                     │  ánh xạ sang tên vật lý
                     ▼
 TẦNG 4 — Lược đồ ánh xạ cục bộ (Local Mapping Schema)
     S1: [MIGNON\KHO_A].KhoA.dbo.TonKho
     S2: [MIGNON\KHO_B].KhoB.dbo.TonKho
     S3: [MIGNON\KHO_C].KhoC.dbo.TonKho

 Khung nhìn hợp nhất tại mỗi site (che giấu phân mảnh):
     CREATE VIEW v_TonKho_ToanHeThong AS
         SELECT * FROM TonKho
         UNION ALL SELECT * FROM [MIGNON\KHO_B].KhoB.dbo.TonKho
         UNION ALL SELECT * FROM [MIGNON\KHO_C].KhoC.dbo.TonKho
```

---

## 11. Đối chiếu với yêu cầu đề bài

| Yêu cầu tối thiểu | Đáp ứng bằng | File |
|---|---|---|
| **1 phương pháp phân mảnh** | Phân mảnh ngang **nguyên thủy** (`TonKho`) **+ dẫn xuất** (`ChiTietNhap`, `ChiTietXuat`) | `01`–`03` |
| **1 phương pháp replication** | **Transactional Replication** danh mục, Publisher = Kho A | `05` |
| **1 distributed transaction** | Điều chuyển 50 sản phẩm A→B qua **MS DTC / 2PC**, có rollback | `06` |
| **1 tình huống concurrency** | Lost update khi 2 phiên cùng xuất kho + deadlock 2 chiều | `07` |
| **1 distributed query** | Tồn kho toàn hệ thống qua Linked Server + `OPENQUERY` | `08` |
| **Đồng bộ dữ liệu** | Replication danh mục + giao tác phân tán cho điều chuyển | `05`, `06` |
| Nhập vật tư tại Kho A | Thủ tục `sp_NhapKho` | `04` |
| Xuất vật tư tại Kho B | Thủ tục `sp_XuatKho` | `04` |
| Kiểm tra tồn kho toàn hệ thống | View `v_TonKho_ToanHeThong` | `08` |
| Điều chuyển giữa 2 kho | Thủ tục `sp_DieuChuyenVatTu` | `06` |

---

## 12. Danh sách file cài đặt

| File | Nội dung | Chạy tại |
|---|---|---|
| `SQL/01_TaoCSDL_KhoA.sql` | Tạo database `KhoA`, 9 bảng, ràng buộc mảnh, dữ liệu mẫu | `MIGNON\KHO_A` |
| `SQL/02_TaoCSDL_KhoB.sql` | Tương tự cho `KhoB` | `MIGNON\KHO_B` |
| `SQL/03_TaoCSDL_KhoC.sql` | Tương tự cho `KhoC` | `MIGNON\KHO_C` |
| `SQL/04_ThuTuc_NghiepVu.sql` | `sp_NhapKho`, `sp_XuatKho`, `sp_CanhBaoTonToiThieu` | Cả 3 site |
| `SQL/05_LinkedServer_Replication.sql` | Tạo Linked Server 2 chiều + Publication `PUB_DanhMuc` | `KHO_A` |
| `SQL/06_DieuChuyen_DistributedTransaction.sql` | `sp_DieuChuyenVatTu` + 4 kịch bản thất bại | `KHO_A` |
| `SQL/07_Concurrency.sql` | Demo lost update, UPDLOCK, rowversion, deadlock | 2 phiên song song |
| `SQL/08_DistributedQuery.sql` | View toàn hệ thống, so sánh Linked Server vs `OPENQUERY` | `KHO_A` |
| `SQL/09_PhanQuyen_Trigger.sql` | Role, trigger chặn ghi sai mảnh, audit | Cả 3 site |

---

## 13. Việc còn phải làm

- [ ] Cài xong 3 instance `KHO_A`, `KHO_B`, `KHO_C` (đang làm)
- [ ] Bật MS DTC và mở firewall cho DTC
- [ ] Bật TCP/IP + SQL Server Browser cho named instance
- [ ] Chạy script `01`–`09` theo thứ tự
- [ ] Chụp màn hình cho báo cáo (cài đặt, Linked Server, Publication, kết quả demo)
- [ ] Viết báo cáo theo đề cương (làm sau, khi đã chạy xong)

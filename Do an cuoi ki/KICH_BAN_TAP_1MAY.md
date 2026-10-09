# TỰ TẬP DEMO TRÊN MỘT MÁY

> Đồ án Cơ sở dữ liệu phân tán · Đề tài 2 — Quản lý kho vật tư đa chi nhánh · Nhóm 2
>
> **Bản dành riêng cho việc tự diễn thử.** Không cần ai bật máy, không cần mạng.
> Mỗi bước ghi rõ **con số phải thấy** — sai số là biết hỏng ở đâu ngay.
>
> Tập xong hai lượt rồi mới dùng `KICH_BAN_THUYET_TRINH.pdf` cho ngày demo thật.

---

## VÌ SAO TẬP MỘT MÁY ĐƯỢC

Ba thể hiện `MIGNON\KHO_A`, `MIGNON\KHO_B`, `MIGNON\KHO_C` vẫn còn nguyên trên
máy, mỗi thể hiện có cơ sở dữ liệu riêng. Hôm demo thật thì `KHO_B` và `KHO_C`
nằm ở máy bạn bè; lúc tập thì trỏ ngược về chính máy mình.

Thứ duy nhất đổi là **địa chỉ** mà Linked Server trỏ tới. **Tên gọi** giữ nguyên
`Mignon\KHO_B`, nên mọi tập lệnh chạy y hệt, không sửa dòng nào.

---

# BƯỚC 0 — Chuẩn bị *(2 phút, chỉ làm một lần)*

## 0.1. Kiểm tra ba dịch vụ đang chạy

Mở **SQL Server Configuration Manager** → **SQL Server Services**. Ba dòng
`SQL Server (KHO_A)`, `(KHO_B)`, `(KHO_C)` phải **Running**.

Hoặc nhanh hơn, mở PowerShell gõ:

```powershell
Get-Service | Where-Object { $_.Name -like 'MSSQL$KHO_*' } | Select-Object Name, Status
```

Phải thấy đủ ba dòng `Running`. Dòng nào `Stopped` thì bấm chuột phải → Start.

## 0.2. Mở SSMS, nối vào `MIGNON\KHO_A`

Chỉ cần **một cửa sổ** này thôi. Mọi thứ chạy từ đây, Linked Server lo phần còn lại.

| Ô | Điền |
|---|---|
| Server name | `MIGNON\KHO_A` |
| Authentication | SQL Server Authentication |
| Login | `sa` |
| Password | `123` |

Nếu báo lỗi chứng chỉ thì tick **Trust server certificate**.

---

# BƯỚC 1 — Chuyển sang chế độ một máy *(1 phút)*

Mở `SQL\13_DoiCheDo_MotMay_BaMay.sql`. Dòng 33 phải là:

```sql
DECLARE @CheDo VARCHAR(10) = 'MOTMAY';
```

Bấm **F5** chạy cả file.

## Kết quả phải thấy

```
ĐANG CHUYỂN SANG CHẾ ĐỘ: MOTMAY
   • Đã gỡ link cũ: Mignon\KHO_B
   ✔ Mignon\KHO_B  ->  localhost,1441
   • Đã gỡ link cũ: Mignon\KHO_C
   ✔ Mignon\KHO_C  ->  localhost,1442
```

Rồi bảng kiểm chứng:

| LinkedServer | TrangThai |
|---|---|
| Mignon\KHO_B | THÔNG — máy bên kia tên: **Mignon** |
| Mignon\KHO_C | THÔNG — máy bên kia tên: **Mignon** |

> Chữ `Mignon` ở đây là **đúng**, vì đang trỏ về chính máy mình. Hôm demo thật
> hai dòng này phải ra `Admin-PC` và `GiaBinh`.

**Nếu thấy `KHÔNG GỠ ĐƯỢC`:** replication còn giữ Linked Server làm Subscriber.
Chạy `SQL\00_ResetToanBo.sql` trước, rồi chạy lại file 13.

---

# BƯỚC 2 — Đưa số liệu về mốc chuẩn *(30 giây)*

Mở `SQL\07b_ResetDeChupLaiAnh.sql`, bấm **F5**.

## Kết quả phải thấy

```
--- SAU KHI RESET (phải là 800 / 150 và không còn phiếu DCA nào) ---
KHO_A   VT009   800
KHO_B   VT009   150

SoPhieuDieuChuyenConLai
0
```

**Ba con số này là mốc.** Mỗi lần muốn tập lại, chỉ cần chạy lại bước 2 — không
phải làm lại bước 1.

---

# BƯỚC 3 — Trong suốt phân mảnh *(1 phút)*

Mở cửa sổ **New Query**, dán:

```sql
USE KhoA;
SELECT 'KHO_A' Site, COUNT(*) SoDong, SUM(SoLuong) Tong FROM dbo.TonKho
UNION ALL
SELECT 'KHO_B', COUNT(*), SUM(SoLuong) FROM [Mignon\KHO_B].KhoB.dbo.TonKho
UNION ALL
SELECT 'KHO_C', COUNT(*), SUM(SoLuong) FROM [Mignon\KHO_C].KhoC.dbo.TonKho;
```

## Kết quả phải thấy

| Site | SoDong | Tong |
|---|---|---|
| KHO_A | 10 | 13 870 |
| KHO_B | 7 | ~5 100 |
| KHO_C | 7 | 7 363 |

Cột `Tong` của KHO_B có thể lệch chút tuỳ bạn đã tập mấy lượt — không sao. Cái
cần đúng là **số dòng 10 / 7 / 7** và câu lệnh chạy được.

**Tập nói:** *"Bảng TonKho được phân mảnh ngang theo mã kho, mỗi kho chỉ giữ dòng
của chính mình. Câu lệnh này gom dữ liệu ba site về một bảng mà người viết không
cần biết dữ liệu nằm ở đâu."*

---

# BƯỚC 4 — Điều chuyển 50 sản phẩm ⭐ *(2 phút)*

Mở `SQL\07_DieuChuyen_GiaoTacPhanTan.sql`.

**Bôi đen từ dòng `PHẦN 3` tới trước dòng `PHẦN 4`**, rồi bấm **F5**.
Đừng chạy cả file — nó sẽ chạy luôn cả bốn kịch bản một lượt, không kịp nói.

## Kết quả phải thấy

Bảng TRƯỚC:

| Site | MaVT | SoLuong |
|---|---|---|
| KHO_A (Trung tâm) | VT009 | **800** |
| KHO_B (Miền Bắc) | VT009 | **150** |

Dòng thông báo:

```
✔ THÀNH CÔNG  DCA001 : KHO_A -> KHO_B  |  VT009 x 50
```

Bảng SAU:

| Site | MaVT | SoLuong |
|---|---|---|
| KHO_A (Trung tâm) | VT009 | **750** |
| KHO_B (Miền Bắc) | VT009 | **200** |

Bảng phiếu — **hai dòng, cùng mã `DCA001`**:

| LuuTai | MaDC | MaKhoNguon | MaKhoDich | SoLuong | TrangThai |
|---|---|---|---|---|---|
| KHO_A | DCA001 | KHO_A | KHO_B | 50 | HOAN_TAT |
| KHO_B | DCA001 | KHO_A | KHO_B | 50 | HOAN_TAT |

**Tập nói:** *"Kho A đi từ 800 xuống 750, Kho B từ 150 lên 200. Tổng không đổi.
Phiếu được ghi ở cả hai site trong cùng một giao tác — không có chuyện một bên có
phiếu còn bên kia không."*

---

# BƯỚC 5 — Kho nguồn không đủ hàng *(1 phút)*

**Bôi đen PHẦN 4**, bấm **F5**.

## Kết quả phải thấy

```
✘ THẤT BẠI - ĐÃ ROLLBACK TOÀN BỘ : KHÔNG ĐỦ HÀNG: kho KHO_A chỉ còn 370,
                                   cần chuyển 999999.
   >>> Đã bắt được lỗi đúng như mong đợi
```

Hai bảng TRƯỚC và SAU của VT001 **giống hệt nhau**: `370` và `450`.

**Tập nói:** *"Thủ tục kiểm tra tồn kho trước khi trừ nên từ chối ngay, không site
nào bị đụng tới. Đây là tầng bảo vệ thứ nhất — chặn từ đầu, chưa cần tới cơ chế
quay lui."*

---

# BƯỚC 6 — LỖI GIỮA CHỪNG ⭐⭐ *(2 phút)*

> Đây là thứ đề bài bắt buộc. Tập kỹ bước này nhất.

**Bôi đen PHẦN 5**, bấm **F5**.

## Kết quả phải thấy

```
✘ THẤT BẠI - ĐÃ ROLLBACK TOÀN BỘ : >>> LỖI MÔ PHỎNG: mất kết nối tới kho đích
                                       giữa chừng <<<
   >>> Giao tác đã bị huỷ, MS DTC rollback cả hai site
```

Hai bảng VT001 **y hệt nhau**: `370` và `450`.
Và `SoPhieu_KhoA` **không đổi** giữa hai lần đếm.

Để ý thêm cột `NgayCapNhat` — nó **không thay đổi**. Đó là bằng chứng mạnh hơn cả
con số: không có lệnh ghi nào chạm vào dòng dữ liệu đó.

**Tập nói:** *"Tham số GayLoiThuNghiem khiến thủ tục bung lỗi đúng vào lúc đã trừ
kho nguồn và đã ghi phiếu, nhưng chưa cộng cho kho đích. Nếu không có cơ chế hai
pha thì 50 đơn vị hàng sẽ bốc hơi. Kết quả: tồn kho y nguyên, số phiếu không đổi,
dữ liệu vẫn nhất quán."*

> **Lưu ý khi tập một máy:** ở chế độ này hai nửa giao tác nằm trên cùng một máy
> nên MS DTC làm việc nhẹ hơn. Hôm demo thật chúng nằm trên hai máy khác nhau —
> đó mới là lúc 2PC thật sự có ý nghĩa. Nhớ nói câu đó khi thuyết trình.

---

# BƯỚC 7 — Tổng kết *(30 giây)*

**Bôi đen PHẦN 6**, bấm **F5**.

Tổng tồn VT009 toàn hệ thống phải là **1370** (`750 + 200 + 420`), bằng đúng con
số trước khi demo (`800 + 150 + 420`).

**Tập nói:** *"Tổng tồn kho trước và sau toàn bộ buổi demo bằng nhau. Mọi thao tác
đều bảo toàn tổng lượng hàng."*

---

# BƯỚC 8 — Phần mềm web *(2 phút)*

Mở **Terminal** trong thư mục `UngDungWeb`:

```
npm run dev
```

Thấy dòng báo server chạy thì mở trình duyệt vào **`http://localhost:3001`**.

Thử ba tab theo thứ tự:

| Tab | Kiểm tra |
|---|---|
| **Tổng quan** | Thanh đầu trang ghi `Mignon\KHO_A` và `TCP : 1440` |
| **Tồn kho toàn hệ thống** | Ra **24 dòng** — 10 của Kho A, 7 của Kho B, 7 của Kho C |
| **Điều chuyển** | Bấm nút đỏ **Mô phỏng lỗi giữa chừng** |

Nút đỏ phải cho **hai bảng giống hệt nhau**. Đó là màn chiếu dễ hiểu nhất.

Tắt server: bấm `Ctrl + C` trong cửa sổ terminal.

---

# TẬP LẠI TỪ ĐẦU

Chỉ cần chạy lại **BƯỚC 2** (`07b_ResetDeChupLaiAnh.sql`). Số liệu về `800 / 150`,
phiếu DCA về 0. Tập bao nhiêu lượt cũng được.

Không phải chạy lại bước 1 trừ khi bạn đã đổi sang chế độ `BAMAY`.

---

# BA ĐIỀU KHÁC VỚI DEMO THẬT

| | Tập một máy | Demo thật |
|---|---|---|
| **Chứng minh ba máy vật lý** | Không làm được — cả ba đều ra `Mignon` | Phải ra `Mignon`, `Admin-PC`, `GiaBinh` |
| **MS DTC** | Không cần bật, ba thể hiện dùng chung DTC nội bộ | **Bắt buộc** chạy `CHAY_BAT_MSDTC.bat` ở cả ba máy |
| **Đồng bộ danh mục** | Sẽ báo lỗi vì replication còn trỏ sang máy bạn bè | Chạy bình thường |

Điều thứ hai là cái bẫy nguy hiểm nhất: tập một máy trơn tru không có nghĩa demo
thật sẽ chạy. Thiếu bước MS DTC là giao tác phân tán chết ngay.

---

# KHI CÓ TRỤC TRẶC

| Hiện tượng | Nguyên nhân | Xử lý |
|---|---|---|
| `Login timeout` khi gọi `[Mignon\KHO_B]` | Dịch vụ KHO_B chưa chạy | Configuration Manager → Start |
| `Could not find server 'Mignon\KHO_B' in sys.servers` | Chưa chạy file 13 | Quay lại BƯỚC 1 |
| Số liệu lệch so với tài liệu này | Đã tập vài lượt chưa reset | Chạy lại BƯỚC 2 |
| `KHÔNG GỠ ĐƯỢC Mignon\KHO_B` | Replication còn giữ làm Subscriber | Chạy `00_ResetToanBo.sql` rồi làm lại BƯỚC 1 |
| Lỗi 451 collation | Thiếu `COLLATE DATABASE_DEFAULT` trong câu `UNION ALL` | Chép lại câu từ tài liệu |
| Web báo `Cannot GET /tonkho` | Gõ thiếu `/api` | Đúng là `/api/tonkho` |

---

# CHUYỂN VỀ CHẾ ĐỘ BA MÁY

Trước hôm lên lớp, mở lại `SQL\13_DoiCheDo_MotMay_BaMay.sql`, sửa dòng 33:

```sql
DECLARE @CheDo VARCHAR(10) = 'BAMAY';
```

Bấm F5. Hai dòng kiểm chứng phải ra **`Admin-PC`** và **`GiaBinh`** — nếu vẫn ra
`Mignon` là chưa ăn, hoặc hai bạn chưa bật máy.

Sau đó làm theo `KICH_BAN_THUYET_TRINH.pdf`.

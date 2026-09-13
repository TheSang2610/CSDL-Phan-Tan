# NGÀY DEMO — BA MÁY CÙNG MỘT CHỖ

> Tài liệu này dành cho **buổi ráp ba máy và bảo vệ đồ án**. Làm theo đúng thứ tự
> từ trên xuống. Tổng thời gian khoảng **45 phút**, trong đó phần demo chính chỉ
> chiếm 10 phút — thời gian còn lại là dựng hệ thống.
>
> Trọng tâm của đề bài nằm ở **GIAI ĐOẠN 4**. Nếu gấp thời gian, hãy bảo đảm
> giai đoạn đó chạy được, các phần khác có thể dùng ảnh đã chụp sẵn.

---

## MANG THEO GÌ

| Món | Ai giữ | Ghi chú |
|---|---|---|
| Laptop đã cài SQL Server | cả ba | instance `KHO_A` / `KHO_B` / `KHO_C` |
| `KhoB.bak` | nhóm trưởng | đưa bạn thứ nhất |
| `KhoC.bak` | nhóm trưởng | đưa bạn thứ hai |
| Thư mục `SQL\` | nhóm trưởng | chép cho cả hai bạn |
| Network ID `a581878f7d00676e` | cả ba | đã join từ ở nhà |
| Dây sạc | cả ba | buổi này máy chạy nặng |

Nếu lớp có Wi-Fi riêng thì tốt, nhưng **không bắt buộc** — ZeroTier chạy qua
mạng nào cũng được, kể cả ba máy dùng ba mạng khác nhau.

---

# GIAI ĐOẠN 0 — Ba máy vào mạng ảo *(10 phút)*

## 0.1. Mỗi máy bật ZeroTier

Nhìn khay đồng hồ góc dưới phải, icon ZeroTier phải **màu cam sáng**, không xám.
Chuột phải icon → **Show Networks** → dòng network phải ghi **OK**, có
**Managed IP** dạng `10.91.x.x`.

## 0.2. Nhóm trưởng duyệt hai máy mới

Vào `https://my.zerotier.com` → mở network `a581878f7d00676e` → tab
**Member Devices** → **tích ô `Auth?`** cho hai dòng mới. Đặt tên cho dễ nhớ:

```
MAY_A_KHO_A     10.91.229.18
MAY_B_KHO_B     10.91.___.___
MAY_C_KHO_C     10.91.___.___
```

**» CHỤP MÀN HÌNH NÀY** — bảng có đủ **ba dòng Authorized**. Đây là ảnh thay cho
`AnhChup\3.1_VPN_ZeroTier\02_ThanhVien_DaDuyet.png` (bản cũ chỉ có một máy).

## 0.3. Ghi lại bảng thông số

Hỏi mỗi bạn chạy trên máy họ:

```sql
SELECT @@SERVERNAME AS TenMayChu;
```

Điền vào đây, lát nữa cần dùng:

| | Tên máy chủ | IP ảo | Cổng |
|---|---|---|---|
| KHO_A | `MIGNON\KHO_A` | `10.91.229.18` | 1440 |
| KHO_B | `____________\KHO_B` | `10.91.___.___` | 1441 |
| KHO_C | `____________\KHO_C` | `10.91.___.___` | 1442 |

## 0.4. Kiểm tra ba máy thấy nhau

Trên **máy KHO_A**, mở PowerShell:

```powershell
Test-NetConnection <IP máy B> -Port 1441
Test-NetConnection <IP máy C> -Port 1442
```

`TcpTestSucceeded` phải là **True** cả hai.

> **Không thông thì DỪNG LẠI, đừng đi tiếp.** Nguyên nhân theo thứ tự hay gặp:
> máy kia chưa chạy `BatTCPIP_VaFirewall.ps1` với quyền admin; máy kia chưa được
> tích `Auth?`; tường lửa của phần mềm diệt virus chặn. Sửa xong mới đi tiếp.

---

# GIAI ĐOẠN 1 — Hai bạn dựng CSDL trên máy mình *(10 phút)*

## 1.1. Phục hồi database

SSMS → chuột phải **Databases** → **Restore Database…** → chọn **Device** →
nút `…` → **Add** → chọn `KhoB.bak` (bạn thứ hai chọn `KhoC.bak`) → **OK**.

Xong phải thấy database `KhoB` (hoặc `KhoC`) trong Object Explorer.

## 1.2. Kiểm tra nhanh

```sql
USE KhoB;   -- máy thứ hai: USE KhoC
SELECT MaKho, COUNT(*) AS SoDong FROM TonKho GROUP BY MaKho;
```

Phải ra **đúng một dòng**, đúng mã kho của mình. Ra nhiều hơn một mã kho nghĩa là
restore nhầm file.

> Bản `.bak` đã gồm sẵn thủ tục nghiệp vụ, 6 trigger và 4 vai trò phân quyền,
> nên **không cần chạy lại** script `01`–`04` và `10`.

---

# GIAI ĐOẠN 2 — Nối ba máy thành một hệ thống *(10 phút)*

Đây là bước duy nhất phải gõ tay. Chỉ sửa **4 dòng**.

## 2.1. Mở `SQL\11_ChuyenSang3May.sql`

Ở **PHẦN 0**, sửa bốn dòng có dấu `<<< SỬA`:

```sql
DECLARE @IP_KhoB      = N'10.91.___.___';      -- IP ảo máy bạn thứ nhất
DECLARE @IP_KhoC      = N'10.91.___.___';      -- IP ảo máy bạn thứ hai
DECLARE @TenMay_KhoB  = N'________\KHO_B';     -- tên máy chủ bạn thứ nhất
DECLARE @TenMay_KhoC  = N'________\KHO_C';     -- tên máy chủ bạn thứ hai
```

Dòng `@IP_KhoA` đã điền sẵn `10.91.229.18`, không phải sửa.

**PHẦN 0 đến PHẦN 2 chạy trên CẢ BA MÁY** — gửi file đã sửa cho hai bạn, họ chỉ
việc mở và bấm F5, không sửa gì thêm.

## 2.2. Vì sao chỉ đổi địa chỉ mà mọi script khác vẫn chạy

Linked Server tách làm hai phần rời nhau:

```sql
@server  = 'Mignon\KHO_B'        -- TÊN GỌI, giữ nguyên
@datasrc = '10.91.x.x,1441'      -- ĐỊA CHỈ THẬT, chỉ đổi cái này
```

Mười script `01`–`10` gọi nhau bằng **tên gọi**. Ta đổi địa chỉ mà tên đó trỏ
tới, giống như đổi số nhà trong danh bạ nhưng vẫn gọi người ta bằng tên cũ.
**Không script nào phải sửa một dòng.**

Đây chính là **trong suốt vị trí** ở mức hạ tầng — nêu được câu này lúc thuyết
trình là ăn điểm.

## 2.3. Chỉ máy KHO_A chạy PHẦN 3

Cập nhật cột `ServerName` trong bảng `Kho`. Cột này phải chứa **tên gọi** Linked
Server, không phải tên máy thật.

---

# GIAI ĐOẠN 3 — Chứng minh đây là ba máy vật lý *(5 phút)*

Trên **máy KHO_A**, chạy **PHẦN 4** của `11_ChuyenSang3May.sql`.

## 3.1. Bảng quan trọng nhất của cả buổi

```sql
SELECT N'KHO_A' AS Site, @@SERVERNAME AS TenMayChuThat,
       CAST(SERVERPROPERTY('MachineName') AS NVARCHAR(60)) AS TenMayTinh
UNION ALL
SELECT N'KHO_B', s.Srv, s.May FROM OPENQUERY([Mignon\KHO_B],
       'SELECT Srv = @@SERVERNAME, May = CAST(SERVERPROPERTY(''MachineName'') AS NVARCHAR(60))') s
UNION ALL
SELECT N'KHO_C', s.Srv, s.May FROM OPENQUERY([Mignon\KHO_C],
       'SELECT Srv = @@SERVERNAME, May = CAST(SERVERPROPERTY(''MachineName'') AS NVARCHAR(60))') s;
```

Kết quả phải ra **ba tên máy tính KHÁC NHAU**. Đó là bằng chứng ba site đang chạy
trên ba máy vật lý riêng biệt, không phải ba thể hiện trên cùng một máy.

**» CHỤP ẢNH NÀY.**

## 3.2. Chứng minh dữ liệu đi qua mạng

```sql
SELECT net_transport, local_net_address, local_tcp_port
FROM   sys.dm_exec_connections WHERE session_id = @@SPID;
```

`net_transport` phải là **TCP**, không phải `Shared memory`.

---

# GIAI ĐOẠN 4 — DEMO CHÍNH *(10 phút)* ⭐

> Đây là phần đề bài bắt buộc:
> *"Kho A chuyển 50 sản phẩm → Kho B. Nếu giao dịch thất bại giữa chừng thì dữ
> liệu phải được xử lý nhất quán."*
>
> Bố trí màn hình: **máy KHO_A chiếu lên máy chiếu**, hai máy kia mở sẵn cửa sổ
> truy vấn để soi dữ liệu phía mình.

## 4.0. Đưa dữ liệu về trạng thái gốc — LÀM TRƯỚC, ĐỪNG QUÊN

Trên máy KHO_A, chạy `SQL\07b_ResetDeChupLaiAnh.sql`.

**Vì sao bắt buộc:** mã phiếu điều chuyển sinh theo công thức *số lớn nhất cộng
một*. Nếu đã chạy thử ở nhà mà không reset, phiếu mới sẽ là `DCA002`, `DCA003`…
và tồn kho tụt thêm 50 mỗi lần — lệch hẳn so với số liệu trong cuốn báo cáo,
thầy đối chiếu sẽ thấy ngay.

Sau khi reset, trạng thái phải đúng như sau:

```
VT009 tại KHO_A : 800
VT009 tại KHO_B : 150      (dưới mức tối thiểu 200, thiếu đúng 50)
Phiếu điều chuyển : không còn phiếu DCA nào
```

## 4.1. Màn 1 — Bối cảnh nghiệp vụ

Mở `SQL\07_DieuChuyen_GiaoTacPhanTan.sql`, bôi đen phần đầu **PHẦN 3**, F5:

```sql
SELECT * FROM dbo.v_TonKho_AB WHERE MaVT = 'VT009';
```

**Nói khi trình bày:**

> *"Kho Miền Bắc báo thiếu bóng đèn LED. Tồn hiện tại 150, mức tồn tối thiểu là
> 200 — thiếu đúng 50 đơn vị. Kho Trung tâm còn 800 nên sẽ điều chuyển sang 50."*

Hai bạn kia cùng lúc chạy trên máy mình để khán giả thấy số liệu nằm ở hai nơi
thật sự khác nhau:

```sql
SELECT * FROM TonKho WHERE MaVT = 'VT009';
```

## 4.2. Màn 2 — Điều chuyển thành công (T1)

Bôi đen khối lệnh gọi thủ tục, F5:

```sql
DECLARE @dc CHAR(6);
EXEC dbo.sp_DieuChuyenVatTu
     @MaKhoDich = 'KHO_B', @MaVT = 'VT009', @SoLuong = 50,
     @NguoiLap  = N'Phòng Điều phối',
     @GhiChu    = N'Bổ sung cho Kho Miền Bắc do dưới mức tồn tối thiểu',
     @MaDC      = @dc OUTPUT;
```

Kết quả mong đợi ở tab **Messages**:

```
✔ THÀNH CÔNG  DCA001 : KHO_A -> KHO_B
```

Chạy tiếp hai lệnh kiểm chứng:

```
KHO_A : 800 -> 750          (giảm đúng 50)
KHO_B : 150 -> 200          (tăng đúng 50)
Phiếu DCA001 có mặt ở CẢ HAI site, trạng thái HOAN_TAT
```

**Nói khi trình bày:**

> *"Một lệnh duy nhất vừa ghi vào hai cơ sở dữ liệu trên hai máy tính khác nhau.
> Tổng số hàng toàn hệ thống không đổi — 50 đơn vị rời Kho A thì đúng 50 đơn vị
> tới Kho B, không thừa không thiếu."*

**» CHỤP ẢNH** — cả tab Results lẫn tab Messages.

## 4.3. Màn 3 — Từ chối khi không đủ hàng (T2)

Chạy **PHẦN 4**: xin chuyển 999 999 đơn vị.

```
✘ THẤT BẠI - ĐÃ ROLLBACK TOÀN BỘ : Kho nguồn KHO_A không đủ hàng...
   >>> Đã bắt được lỗi đúng như mong đợi
```

Bảng **SAU** phải **giống hệt** bảng **TRƯỚC**.

**Nói khi trình bày:**

> *"Hệ thống kiểm tra tồn kho trước khi động vào dữ liệu, nên giao tác bị từ chối
> ngay từ đầu. Đây là tầng bảo vệ thứ nhất."*

## 4.4. Màn 4 — Lỗi giữa chừng ⭐ ĐÂY LÀ CÂU TRẢ LỜI CỦA ĐỀ BÀI

Chạy **PHẦN 5**. Tham số `@GayLoiThuNghiem = 1` khiến thủ tục **bung lỗi ngay sau
khi đã trừ kho nguồn và đã ghi phiếu, nhưng trước khi cộng cho kho đích**.

```sql
EXEC dbo.sp_DieuChuyenVatTu
     @MaKhoDich = 'KHO_B', @MaVT = 'VT001', @SoLuong = 50,
     @GayLoiThuNghiem = 1,          -- cố tình hỏng giữa chừng
     @MaDC = @dc3 OUTPUT;
```

**Nói khi trình bày — đây là đoạn quan trọng nhất, nên nói chậm:**

> *"Lần này chúng em cố tình cho giao tác chết đúng vào thời điểm nguy hiểm nhất:
> Kho A đã bị trừ 50, phiếu đã được ghi, nhưng chưa kịp cộng cho Kho B. Nếu hệ
> thống chỉ là hai database rời rạc thì 50 đơn vị hàng này sẽ bốc hơi — Kho A mất
> mà Kho B không nhận được."*

Rồi chạy phần kiểm chứng:

```
--- SAU (tồn kho PHẢI y nguyên, số phiếu PHẢI không đổi) ---
KHO_A : 250     <- không đổi
KHO_B : 140     <- không đổi
SoPhieu_KhoA    <- không đổi
```

> *"Tồn kho hai bên y nguyên, không sinh thêm phiếu nào. MS DTC đã quay lui cả
> hai máy về trạng thái trước giao tác. Đây chính là tính nhất quán mà đề bài
> yêu cầu."*

**» CHỤP ẢNH** — đây là ảnh quan trọng nhất của cả cuốn báo cáo.

## 4.5. Cơ chế đứng sau — phòng khi thầy hỏi

| Thành phần | Vai trò |
|---|---|
| `BEGIN DISTRIBUTED TRANSACTION` | Mở giao tác trải trên nhiều máy chủ |
| **MS DTC** | Trọng tài hai pha: hỏi cả hai site "sẵn sàng chưa?", chỉ khi **cả hai** trả lời sẵn sàng mới ra lệnh ghi thật |
| `SET XACT_ABORT ON` | Bắt buộc với giao tác phân tán — lỗi nào cũng huỷ toàn bộ |
| `WITH (UPDLOCK, HOLDLOCK)` | Giữ khoá tới hết giao tác, chống hai phiên cùng chuyển một vật tư |
| `XACT_STATE()` | Kiểm tra giao tác còn cứu được không trước khi quay lui |

**Nếu thầy hỏi "làm sao biết chắc nó rollback ở cả hai máy?"** — bảo bạn giữ máy
KHO_B chạy `SELECT * FROM TonKho WHERE MaVT = 'VT001';` ngay trên máy họ. Số liệu
đọc từ chính máy đó, không qua máy bạn, nên không thể nguỵ tạo.

---

# GIAI ĐOẠN 5 — Các mục còn lại *(10 phút)*

| Mục | Chạy ở đâu | Nội dung |
|---|---|---|
| 3.7a Nhập dữ liệu | **cả ba máy** | `SQL\04` — mỗi kho nhập hàng của mình |
| 3.7b Hiển thị | KHO_A | `SQL\09` PHẦN 2 |
| 3.7c Thống kê | KHO_A | `SQL\09` PHẦN 3–8 |
| 3.7d Trigger | **cả ba máy** | `SQL\10` PHẦN 10 |
| 3.7e Tương tranh | KHO_A, hai cửa sổ | `SQL\08` |

## Câu lệnh đắt giá nhất, bảo hai bạn chạy trên máy họ

```sql
SELECT * FROM dbo.v_TonKho_ToanHeThong;
```

Ngắn nhưng chứng minh được điều mà cả buổi demo hướng tới: **site nào cũng nhìn
được toàn hệ thống**, không phải chỉ máy trung tâm. Đó là *trong suốt vị trí*, và
là thứ phân biệt một hệ phân tán thật với ba database rời rạc đặt cạnh nhau.

## Về Replication — lời khuyên thật lòng

**Đừng dựng lại replication trong buổi này.** Nó cần hai máy gọi nhau bằng **tên
máy** chứ không chỉ IP — phải sửa file `hosts` và tạo SQL Server Alias ở cả ba
máy, cả bản 32-bit lẫn 64-bit. Tốn ít nhất một tiếng và **rủi ro làm hỏng luôn
Publication đang chạy tốt**.

Mục 3.6 dùng ảnh đã chụp. Replication là cơ chế bên trong SQL Server, hoạt động y
hệt dù hai thể hiện nằm ở đâu. Trong báo cáo ghi rõ hai giai đoạn triển khai —
sự trung thực đó được đánh giá cao hơn việc cố làm tất cả rồi hỏng giữa buổi.

---

# XỬ LÝ SỰ CỐ

| Lỗi | Nguyên nhân | Cách sửa |
|---|---|---|
| `Error: 258 — wait operation timed out` | Gõ sai IP, hoặc máy kia chưa vào mạng | Kiểm tra lại IP ảo trên trang ZeroTier |
| `Login failed for user 'sa'` | Máy kia không bật Mixed Mode, hoặc mật khẩu khác | `ALTER LOGIN sa ENABLE; ALTER LOGIN sa WITH PASSWORD='123';` |
| `Msg 7411` — server not configured for RPC | Thiếu tuỳ chọn RPC trên Linked Server | Chạy lại PHẦN 2 của `11_ChuyenSang3May.sql` |
| `Msg 8501` — MSDTC unavailable | MS DTC chưa mở cho mạng | `dcomcnfg` → Local DTC → Security → tick Network DTC Access |
| `Msg 4121 — cannot find fn_MaKhoHienTai` | Cửa sổ truy vấn đang ở database `master` | Chọn đúng `KhoA`/`KhoB`/`KhoC` ở ô dropdown SSMS |
| Giao tác treo không phản hồi | Một phiên khác đang giữ khoá | Đóng bớt cửa sổ truy vấn cũ, hoặc khởi động lại dịch vụ SQL |

---

# PHƯƠNG ÁN DỰ PHÒNG

Mạng trục trặc, hai bạn không tới được, hoặc hết giờ — chạy lại
`SQL\05_LinkedServer.sql` trên ba thể hiện của máy nhóm trưởng. Hệ thống trở về
mô hình một máy trong **hai phút** và demo diễn ra bình thường.

**Toàn bộ 53 ảnh minh chứng đã chụp vẫn nguyên giá trị.** Mô hình ba máy là phần
cộng thêm cho mục 3.1 và 3.2, không phải thứ chống đỡ cả đồ án.

---

# TÓM TẮT — TICK TRONG BUỔI

- [ ] Ba máy online trên ZeroTier, đủ ba dòng Authorized → » chụp
- [ ] `Test-NetConnection` tới cổng 1441 và 1442 đều True
- [ ] Hai bạn restore xong `KhoB.bak` / `KhoC.bak`
- [ ] Sửa 4 dòng trong `11_ChuyenSang3May.sql`, chạy trên cả ba máy
- [ ] PHẦN 4: bảng ba tên máy tính khác nhau → » chụp
- [ ] Chạy `07b_ResetDeChupLaiAnh.sql` **trước khi demo**
- [ ] T1 — chuyển 50 thành công, `DCA001` có ở hai site → » chụp
- [ ] T2 — không đủ hàng, bị từ chối → » chụp
- [ ] **T3 — lỗi giữa chừng, dữ liệu y nguyên → » chụp (ảnh quan trọng nhất)**
- [ ] Hai bạn chạy `v_TonKho_ToanHeThong` trên máy mình → » chụp
- [ ] `SQL\10` PHẦN 10 trên KHO_B để thấy trigger chặn sửa danh mục → » chụp

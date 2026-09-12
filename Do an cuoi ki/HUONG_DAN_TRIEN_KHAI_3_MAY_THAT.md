# TRIỂN KHAI HỆ THỐNG LÊN 3 MÁY VẬT LÝ

> Dành cho **bạn** — người điều phối. Hai bạn kia mỗi người nhận **một file riêng**
> (`GUI_CHO_BAN_KHO_B.md` / `GUI_CHO_BAN_KHO_C.md`) và làm ở nhà trước.
>
> Mục tiêu: KHO_A ở máy bạn, KHO_B ở máy bạn thứ nhất, KHO_C ở máy bạn thứ hai,
> ba máy nối nhau qua ZeroTier, chạy được **truy vấn phân tán** và **giao tác
> phân tán 2PC** thật giữa ba máy.

---

## Nguyên tắc để không phải sửa 10 script

Mười script hiện gọi nhau bằng tên `[Mignon\KHO_B]` và `[Mignon\KHO_C]`. Đem sang
máy khác thì tên máy đổi thành `LAPTOP-BAN1\KHO_B` — khác hoàn toàn.

Không cần sửa script. Linked Server có **hai phần tách rời**:

```
   @server   = TÊN GỌI       ->  giữ nguyên  'Mignon\KHO_B'
   @datasrc  = ĐỊA CHỈ THẬT  ->  đổi thành   '10.147.20.51,1441'
```

Giữ nguyên cái tên mọi script đang dùng, chỉ đổi địa chỉ mà cái tên đó trỏ tới —
như đổi số nhà trong danh bạ nhưng vẫn gọi người đó bằng tên cũ.

File `SQL/11_ChuyenSang3May.sql` làm đúng việc này.

> **Câu này nên nói khi thuyết trình:** "Nhóm chuyển hệ thống từ một máy sang ba
> máy vật lý mà **không sửa một dòng nào** trong mười script nghiệp vụ — chỉ đổi
> ánh xạ ở tầng Linked Server. Đó là **trong suốt vị trí** ở mức hạ tầng."

---

# GIAI ĐOẠN 1 — TRƯỚC HÔM LÊN LỚP

## 1.1. Chạy script mở cổng trên máy bạn

Chưa chạy thì bây giờ chạy. **Run as administrator**:

```powershell
powershell -ExecutionPolicy Bypass -File "D:\CSDL PHAN TAN\Do an cuoi ki\BatTCPIP_VaFirewall.ps1"
```

## 1.2. Mở MS DTC cho mạng trên máy bạn

Đây là thứ cho phép giao tác phân tán chạy **giữa hai máy khác nhau**. Trên một máy
thì MS DTC không cần cấu hình gì, nhưng qua mạng thì bắt buộc.

1. **Windows + R** → `dcomcnfg` → OK
2. Bung **Component Services** → **Computers** → **My Computer** →
   **Distributed Transaction Coordinator**
3. Chuột phải **Local DTC** → **Properties** → tab **Security**
4. Tick:

   ```
   ☑ Network DTC Access
   ☑ Allow Inbound
   ☑ Allow Outbound
   ◉ No Authentication Required
   ☑ Enable XA Transactions
   ```

5. **OK** → hỏi restart dịch vụ → **Yes**

📷 Chụp tab Security → `AnhChup\3.2_LinkMang\08_MSDTC_NetworkAccess.png`

> Chọn **No Authentication Required** vì ba máy không cùng miền Windows. Trong
> doanh nghiệp thật sẽ dùng **Mutual Authentication** — nêu ý này trong báo cáo
> để cho thấy nhóm hiểu đánh đổi, không phải chọn bừa.

## 1.3. Tạo network ZeroTier và gửi cho hai bạn

Làm theo bước A3–A5 của `HUONG_DAN_ZEROTIER_3MAY.md`.

Xong rồi gửi cho mỗi bạn **ba thứ**:

```
Ban thu nhat:  GUI_CHO_BAN_KHO_B.md  + Network ID ZeroTier (16 ky tu)
Ban thu hai :  GUI_CHO_BAN_KHO_C.md  + Network ID ZeroTier (16 ky tu)

Gui dung file cua tung nguoi. Moi file da dien san ten instance va
cong TCP rieng, nen ho chi viec chep nguyen, khong phai tu doi.
```

## 1.4. Sao lưu hai database để mang đi

Chạy ở máy bạn — mỗi file chỉ khoảng **3–4 MB**, gửi Zalo được:

```powershell
$out = "D:\CSDL PHAN TAN\Do an cuoi ki\BanSaoMangDi"
New-Item -ItemType Directory -Force -Path $out | Out-Null

sqlcmd -S "Mignon\KHO_B" -U sa -P 123 -C -Q "BACKUP DATABASE KhoB TO DISK='$out\KhoB.bak' WITH INIT, FORMAT"
sqlcmd -S "Mignon\KHO_C" -U sa -P 123 -C -Q "BACKUP DATABASE KhoC TO DISK='$out\KhoC.bak' WITH INIT, FORMAT"

Get-ChildItem $out | Select-Object Name, @{n='MB';e={[math]::Round($_.Length/1MB,1)}}
```

Gửi `KhoB.bak` cho bạn thứ nhất, `KhoC.bak` cho bạn thứ hai. Bảo họ để ở `D:\` hoặc `C:\`.

## 1.5. Thu thập thông tin từ hai bạn

Trước hôm lên lớp phải có đủ bảng này:

| | Tên máy chủ (`@@SERVERNAME`) | IP ảo ZeroTier | Cổng |
|---|---|---|---|
| Máy bạn — KHO_A | `MIGNON\KHO_A` | `10.147.___.___` | 1440 |
| Bạn 1 — KHO_B | `_______________\KHO_B` | `10.147.___.___` | 1441 |
| Bạn 2 — KHO_C | `_______________\KHO_C` | `10.147.___.___` | 1442 |

---

# GIAI ĐOẠN 2 — HÔM LÊN LỚP (khoảng 30–45 phút)

## Bước 1 — Ba máy vào mạng ảo, xác nhận thấy nhau *(5 phút)*

Cả ba bật ZeroTier. Bạn vào `my.zerotier.com` kiểm tra đủ **ba dòng** trong mục
**Members**, cả ba đều đã tick **Auth?** và có Managed IP.

📷 `AnhChup\3.1_VPN_ZeroTier\04_BaMay_TrongMangAo.png` ← **ảnh đắt nhất của mục 3.1**

Trên máy bạn, PowerShell (thay IP thật):

```powershell
Test-NetConnection 10.147.20.51 -Port 1441
Test-NetConnection 10.147.20.77 -Port 1442
```

Cả hai phải ra `TcpTestSucceeded : True`.

📷 `AnhChup\3.2_LinkMang\04_BaMay_PingThau.png`

> Nếu `PingSucceeded` True nhưng `TcpTestSucceeded` False → máy đó chưa chạy khối
> PowerShell mở cổng ở bước 5 của tờ hướng dẫn, hoặc firewall chặn.

## Bước 2 — Hai bạn phục hồi database *(5 phút)*

Mỗi bạn mở SSMS, connect `.\KHO_B`, New Query, chạy (đổi đường dẫn cho đúng):

```sql
RESTORE DATABASE KhoB FROM DISK = N'D:\KhoB.bak' WITH REPLACE;
GO
USE KhoB;
SELECT MaKho, COUNT(*) AS SoDong FROM TonKho GROUP BY MaKho;
```

Phải ra đúng một dòng `KHO_B  7`.

Bạn thứ hai làm y hệt với `KhoC.bak` → `KHO_C  7`.

> Nếu `RESTORE` báo lỗi đường dẫn file dữ liệu, thêm `MOVE`:
> ```sql
> RESTORE DATABASE KhoB FROM DISK = N'D:\KhoB.bak' WITH REPLACE,
>   MOVE 'KhoB'     TO 'C:\Data\KhoB.mdf',
>   MOVE 'KhoB_log' TO 'C:\Data\KhoB_log.ldf';
> ```
> Nhớ tạo sẵn thư mục `C:\Data` trước.

## Bước 3 — Nối lại ba đường liên kết *(10 phút)*

Mở `SQL/11_ChuyenSang3May.sql`. **Sửa 6 dòng** ở PHẦN 0 và PHẦN 1 theo bảng thông
tin đã thu thập — nhớ sửa ở **cả hai chỗ**, PHẦN 1 khai báo lại biến.

Rồi **cả ba máy** cùng chạy **PHẦN 1 và PHẦN 2**.

Mỗi máy phải thấy hai dòng `✔ THÔNG`.

📷 `AnhChup\3.2_LinkMang\09_LinkedServer_TroSangIPAo.png` — chụp bảng có cột
`DiaChiThat` là IP ảo, không còn là tên máy.

Sau đó **chỉ máy KHO_A** chạy **PHẦN 3** (cập nhật bảng `Kho`).

## Bước 4 — Bài kiểm tra quyết định *(10 phút)*

Ở máy KHO_A chạy **PHẦN 4** của file 11.

**4.1 — ba máy vật lý khác nhau.** Đây là bảng quan trọng nhất cả đồ án:

```
Site    TenMayChuThat          TenMayTinh
KHO_A   MIGNON\KHO_A           MIGNON
KHO_B   LAPTOP-BAN1\KHO_B      LAPTOP-BAN1     ← tên máy KHÁC NHAU
KHO_C   LAPTOP-BAN2\KHO_C      LAPTOP-BAN2
```

📷 `AnhChup\3.2_LinkMang\10_BaMayVatLyKhacNhau.png`

**4.3 — truy vấn phân tán** phải vẫn ra `KHO_A 10 / KHO_B 7 / KHO_C 7`.

📷 `AnhChup\3.2_LinkMang\11_TruyVanPhanTan_3May.png`

**4.4 — giao tác phân tán 2PC qua mạng.** Phép thử nặng nhất. Ra
`✔ GIAO TÁC PHÂN TÁN QUA MẠNG THÀNH CÔNG` nghĩa là MS DTC đã bắt tay được giữa
**hai máy vật lý thật**.

📷 `AnhChup\3.2_LinkMang\12_GiaoTacPhanTan_QuaMang.png` ← **ảnh giá trị nhất**

## Bước 5 — Hai bạn tự chạy trên máy mình *(5 phút)*

Cho mỗi bạn mở file `09_TruyVanPhanTan_ThongKe.sql`, chọn database của mình
(`KhoB` / `KhoC`) ở ô dropdown, bôi đen **PHẦN 2** rồi F5.

Vẫn ra đủ 24 dòng của cả ba kho — nhưng lệnh phát đi **từ máy của họ**.

📷 Mỗi bạn một ảnh → `05_BanA_TruyVan_TuMayMinh.png`, `06_BanB_TruyVan_TuMayMinh.png`

---

# XỬ LÝ SỰ CỐ

| Triệu chứng | Nguyên nhân thường gặp | Cách sửa |
|---|---|---|
| `Login failed for user 'sa'` | Máy kia cài Windows Auth, không phải Mixed Mode | SSMS → chuột phải tên server → Properties → Security → chọn **SQL Server and Windows Authentication**, rồi restart service |
| `Login failed for user 'sa'` dù đã Mixed Mode | Tài khoản `sa` đang bị khoá | `ALTER LOGIN sa ENABLE; ALTER LOGIN sa WITH PASSWORD='123';` |
| Ping được nhưng `TcpTestSucceeded False` | Chưa chạy khối mở cổng, hoặc firewall | Chạy lại bước 5 tờ hướng dẫn bằng quyền Admin |
| `Msg 7391` — không khởi tạo được giao tác phân tán | **MS DTC chưa mở cho mạng** | Làm lại mục 1.2 trên **cả hai máy** liên quan |
| `Msg 8501` — MSDTC không khả dụng | Dịch vụ MSDTC dừng | `Start-Service MSDTC` |
| 2PC treo rồi timeout | Firewall chặn RPC động của DTC | Kiểm tra luật firewall cho `msdtc.exe` ở cả hai máy |
| `Msg 7411` — not configured for DATA ACCESS | Tuỳ chọn link bị tắt | Chạy lại PHẦN 1 của file 11 |
| Truy vấn rất chậm | Bình thường — VPN chậm hơn bộ nhớ chung | Đã đặt `query timeout = 120`, cứ chờ |

---

# VỀ REPLICATION TRÊN 3 MÁY

**Lời khuyên thật lòng: hôm lên lớp đừng dựng lại replication.**

Replication qua VPN đòi hỏi hai máy **gọi được nhau bằng tên máy**, không chỉ bằng
IP — phải sửa file `hosts` và tạo SQL Server Alias ở cả ba máy. Dễ hỏng, tốn cả
tiếng, và **rủi ro làm mất luôn Publication đang chạy tốt trên máy bạn**.

Cách làm khôn ngoan hơn:

- **Mục 3.6 (Publication)** — dùng ảnh đã chụp trên mô hình 1 máy. Replication
  là cơ chế **bên trong SQL Server**, hoạt động y hệt dù hai instance ở đâu.
- **Mục 3.1, 3.2** — dùng ảnh 3 máy thật chụp hôm lên lớp.
- Trong báo cáo ghi rõ hai giai đoạn triển khai. **Thầy đánh giá cao sự trung
  thực và việc nhóm hiểu vì sao chọn như vậy**, hơn là cố làm tất cả một lúc rồi
  hỏng giữa buổi.

Nếu vẫn muốn làm đầy đủ thì cần thêm, ở **cả ba máy**:

1. Sửa `C:\Windows\System32\drivers\etc\hosts` (mở Notepad bằng quyền Admin):
   ```
   10.147.20.35   MIGNON
   10.147.20.51   LAPTOP-BAN1
   10.147.20.77   LAPTOP-BAN2
   ```
2. Tạo **SQL Server Alias**: `SQLServerManager16.msc` → **SQL Native Client 11.0
   Configuration** → **Aliases** → New Alias
   ```
   Alias Name:   LAPTOP-BAN1\KHO_B
   Port:         1441
   Protocol:     TCP/IP
   Server:       10.147.20.51
   ```
   Làm cho cả bản 32-bit lẫn 64-bit.
3. Gỡ Publication cũ rồi chạy lại `06_Replication_DongBoDanhMuc.sql` với
   `@subscriber` là **tên máy thật** của hai bạn.

Dự trù ít nhất **một tiếng** và nên thử trước ở nhà, đừng thử lần đầu ngay hôm demo.

---

# PHƯƠNG ÁN QUAY VỀ 1 MÁY

Hôm demo mạng trục trặc thì chạy lại `05_LinkedServer.sql` trên cả ba instance
của máy bạn — hệ thống về mô hình 1 máy, dùng được ngay trong hai phút.

**Toàn bộ ảnh minh chứng đã chụp vẫn còn nguyên giá trị.** Mô hình 3 máy là phần
cộng thêm cho mục 3.1 và 3.2, không phải thứ chống đỡ cả đồ án.

---

# TÓM TẮT

**Trước hôm lên lớp**
- [ ] Chạy `BatTCPIP_VaFirewall.ps1` trên máy bạn
- [ ] Mở MS DTC cho mạng trên máy bạn → 📷
- [ ] Tạo network ZeroTier, lấy Network ID
- [ ] Gửi bạn thứ nhất: `GUI_CHO_BAN_KHO_B.md` + Network ID + `KhoB.bak`
- [ ] Gửi bạn thứ hai: `GUI_CHO_BAN_KHO_C.md` + Network ID + `KhoC.bak`
- [ ] Thu đủ tên máy chủ và IP ảo của hai bạn
- [ ] Điền sẵn 6 dòng thông số vào `11_ChuyenSang3May.sql`

**Hôm lên lớp**
- [ ] Ba máy vào mạng ảo, duyệt Auth → 📷
- [ ] `Test-NetConnection` thông cả hai → 📷
- [ ] Hai bạn `RESTORE` database
- [ ] Ba máy chạy PHẦN 1 + 2 của file 11 → 📷
- [ ] Máy KHO_A chạy PHẦN 3 rồi PHẦN 4 → 📷 ×3
- [ ] Hai bạn chạy truy vấn phân tán từ máy mình → 📷 ×2

# GỬI HAI BẠN — CÀI TRƯỚC Ở NHÀ

> Bạn nhận file này sẽ làm **một máy kho** trong đồ án CSDL phân tán của nhóm.
> Hôm lên lớp ba máy nối với nhau là chạy được ngay — nhưng phải **cài sẵn ở nhà**,
> vì riêng việc tải SQL Server đã mất gần một tiếng.
>
> Làm theo đúng thứ tự. Chỗ nào kẹt thì chụp màn hình gửi lại.

**Bạn được giao instance tên gì:**

| Bạn | Tên instance phải đặt | Database sẽ dùng |
|---|---|---|
| Bạn thứ nhất | `KHO_B` | `KhoB` |
| Bạn thứ hai | `KHO_C` | `KhoC` |

Dưới đây viết là `KHO_B`, bạn thứ hai thì thay hết thành `KHO_C`.

---

## BƯỚC 1 — Kiểm tra máy có đủ chỗ

Cần **ít nhất 10 GB trống**. Mở **This PC** xem ổ C hoặc ổ D còn bao nhiêu.
Không đủ thì xoá bớt rồi hãy cài.

---

## BƯỚC 2 — Tải SQL Server 2022 Developer Edition

1. Vào `https://www.microsoft.com/en-us/sql-server/sql-server-downloads`
2. Kéo xuống mục **Developer** → bấm **Download now**
   (bản này **miễn phí**, đầy đủ tính năng, không phải bản Express)
3. Chạy file vừa tải → chọn ô **Custom** → bấm **Install**
4. Nó tải tiếp khoảng 1 GB, chờ 15–30 phút tuỳ mạng

---

## BƯỚC 3 — Cài đặt

Trình **SQL Server Installation Center** mở ra:

1. Bên trái chọn **Installation** → bấm **New SQL Server standalone installation**
2. **Edition**: chọn **Developer** → Next
3. **License Terms**: tick **I accept** → Next
4. **Microsoft Update**: bỏ trống → Next
5. **Install Rules**: nếu có cảnh báo vàng về **Firewall** thì kệ nó, Next
6. **Feature Selection**: tick đúng **ba mục** sau

   ```
   ☑ Database Engine Services
   ☑ SQL Server Replication          ← QUAN TRỌNG, thiếu là hỏng cả đồ án
   ☑ Full-Text and Semantic Extractions
   ```
   → Next

7. **Instance Configuration** — 📷 **CHỤP MÀN HÌNH NÀY**

   ```
   ◉ Named instance:   KHO_B          ← gõ đúng chữ này, VIẾT HOA, có gạch dưới
     Instance ID:      KHO_B          (tự điền theo)
   ```
   → Next

8. **Server Configuration** — quan trọng, đừng bỏ qua

   Tìm dòng **SQL Server Agent**, đổi cột **Startup Type** từ `Manual` thành
   **`Automatic`**.

   📷 **CHỤP MÀN HÌNH NÀY** → Next

9. **Database Engine Configuration** → tab **Server Configuration**

   ```
   ◉ Mixed Mode (SQL Server authentication and Windows authentication)

   Enter password:    123
   Confirm password:  123
   ```

   ⚠️ Mật khẩu phải đúng là **`123`** — cả ba máy dùng chung, khác là không nối được.

   Bên dưới bấm nút **Add Current User**.

   📷 **CHỤP MÀN HÌNH NÀY** → Next

10. **Ready to Install** → 📷 chụp → bấm **Install**
11. Chờ 15–25 phút → màn hình **Complete** → 📷 chụp → **Close**

---

## BƯỚC 4 — Cài SSMS (công cụ có giao diện)

1. Vào `https://aka.ms/ssmsfullsetup`
2. Chạy file tải về → bấm **Install** → chờ 10–15 phút → **Close**
3. Máy hỏi khởi động lại thì bấm **Restart**

---

## BƯỚC 5 — Mở đường mạng cho máy khác vào được

Máy bạn vừa cài xong thì **chỉ mình nó nói chuyện với nó**. Phải mở cổng TCP.

1. Bấm **Start** → gõ `powershell`
2. Ở kết quả **Windows PowerShell**, bấm **chuột phải** → **Run as administrator**
3. Windows hỏi *"Do you want to allow..."* → **Yes**
4. Dán nguyên khối dưới đây vào rồi Enter
   (bạn thứ hai đổi `KHO_B` → `KHO_C` và `1441` → `1442`)

```powershell
$Ten = 'KHO_B'; $Cong = 1441

$g = "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL16.$Ten\MSSQLServer\SuperSocketNetLib\Tcp"
Set-ItemProperty $g -Name Enabled -Value 1
Set-ItemProperty $g -Name ListenOnAllIPs -Value 1
Set-ItemProperty "$g\IPAll" -Name TcpPort -Value "$Cong"
Set-ItemProperty "$g\IPAll" -Name TcpDynamicPorts -Value ''

New-NetFirewallRule -DisplayName "CSDLPT SQL $Ten" -Direction Inbound -Protocol TCP -LocalPort $Cong -Action Allow -Profile Any
New-NetFirewallRule -DisplayName "CSDLPT Browser" -Direction Inbound -Protocol UDP -LocalPort 1434 -Action Allow -Profile Any
New-NetFirewallRule -DisplayName "CSDLPT MSDTC" -Direction Inbound -Program '%SystemRoot%\System32\msdtc.exe' -Action Allow -Profile Any

Restart-Service "MSSQL`$$Ten" -Force
Start-Service "SQLAgent`$$Ten"
Start-Service SQLBrowser
Start-Service MSDTC
Set-Service MSDTC -StartupType Automatic

Get-Service "MSSQL`$$Ten","SQLAgent`$$Ten",SQLBrowser,MSDTC | Format-Table Name,Status,StartType
```

📷 **Chụp kết quả** — bốn dòng phải đều `Running`.

---

## BƯỚC 6 — Mở MS DTC cho mạng

Đây là thứ cho phép **chuyển hàng giữa hai kho mà không mất hàng giữa chừng**.
Không mở thì phần quan trọng nhất của đồ án chạy không được.

1. Bấm **Windows + R** → gõ `dcomcnfg` → **OK**
2. Bên trái bung lần lượt:
   **Component Services** → **Computers** → **My Computer** →
   **Distributed Transaction Coordinator**
3. Chuột phải **Local DTC** → **Properties**
4. Sang tab **Security**, tick đúng các ô sau:

   ```
   ☑ Network DTC Access
   ☑ Allow Inbound
   ☑ Allow Outbound
   ◉ No Authentication Required      ← chọn nút tròn NÀY
   ☑ Enable XA Transactions
   ```

5. Bấm **OK** → nó hỏi khởi động lại dịch vụ → **Yes**

📷 **CHỤP MÀN HÌNH TAB SECURITY NÀY** — dùng cho báo cáo.

---

## BƯỚC 7 — Cài ZeroTier và vào mạng của nhóm

1. Vào `https://www.zerotier.com/download/` → tải bản **Windows** → cài (bấm Next hết)
2. Nhìn góc dưới phải màn hình (khay đồng hồ), tìm icon **ZeroTier** hình ⊘ màu cam
   (không thấy thì bấm mũi tên `^` để bung ra)
3. **Chuột phải** vào icon đó → **Join New Network...**
4. Dán **Network ID** mà bạn nhóm trưởng gửi → bấm **Join**
5. Nhắn cho nhóm trưởng: *"mình join rồi, duyệt giúp"*
   (bạn ấy phải tick ô **Auth?** trên trang quản lý thì bạn mới vào được)
6. Chờ khoảng 10 giây, chuột phải icon ZeroTier → **Show Networks**
   → thấy dòng network có **Managed IP** dạng `10.147.x.x`

📷 **Chụp lại và gửi IP này cho nhóm trưởng.**

---

## BƯỚC 8 — Gửi lại ba thông tin

Mở **SSMS** → Connect vào `.\KHO_B` (có dấu chấm và dấu gạch chéo ngược) →
bấm **New Query** → dán và chạy:

```sql
SELECT @@SERVERNAME                                  AS TenMayChu,
       CAST(SERVERPROPERTY('MachineName') AS NVARCHAR(60)) AS TenMayTinh,
       CAST(SERVERPROPERTY('Edition')     AS NVARCHAR(60)) AS PhienBan;
```

Chụp kết quả gửi nhóm trưởng, kèm:

```
1. Tên máy chủ  (cột TenMayChu, ví dụ  LAPTOP-ABC\KHO_B)
2. IP ảo ZeroTier  (ví dụ  10.147.20.51)
3. Ảnh chụp các bước ở trên
```

---

## TÓM TẮT — TICK KHI XONG

- [ ] Ổ đĩa còn trên 10 GB
- [ ] Cài SQL Server 2022 **Developer**, instance tên **`KHO_B`** (hoặc `KHO_C`)
- [ ] Có tick **SQL Server Replication** lúc chọn tính năng
- [ ] SQL Server Agent để **Automatic**
- [ ] **Mixed Mode**, mật khẩu `sa` là **`123`**
- [ ] Cài SSMS
- [ ] Chạy khối PowerShell mở cổng (bước 5)
- [ ] Mở **MS DTC** cho mạng (bước 6)
- [ ] Cài ZeroTier, join network, báo nhóm trưởng duyệt
- [ ] Gửi lại **tên máy chủ** + **IP ảo** + ảnh chụp

> Tổng thời gian khoảng **1,5 tiếng**, phần lớn là ngồi chờ tải và cài.
> Làm xong ở nhà thì hôm lên lớp chỉ mất 30 phút là cả nhóm demo được.

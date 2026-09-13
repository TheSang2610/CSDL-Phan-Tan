# KHO B — CÀI TRƯỚC Ở NHÀ

> Bạn nhận file này sẽ làm **máy KHO B** (Kho Miền Bắc, Bắc Ninh) trong đồ án CSDL phân tán
> của nhóm. Hôm lên lớp ba máy nối với nhau là chạy được ngay — nhưng **phải cài
> xong ở nhà trước**, vì riêng việc tải SQL Server đã mất gần một tiếng.
>
> Làm theo đúng thứ tự. Chỗ nào kẹt thì chụp màn hình gửi lại cho nhóm trưởng.

## Bốn thông số của riêng bạn

| Mục | Giá trị |
|---|---|
| Tên instance phải đặt | **`KHO_B`** |
| Cổng TCP | **`1441`** |
| Mật khẩu tài khoản `sa` | **`123`** |
| Network ID ZeroTier | **`a581878f7d00676e`** |

Trong cả file này mọi chỗ cần `KHO_B` và `1441` đều **đã điền sẵn đúng cho bạn**
— chép nguyên, không phải sửa gì.

> **Ba điều tuyệt đối không được đổi**, vì các script của nhóm gọi đích danh:
> tên instance phải là `KHO_B`, mật khẩu `sa` phải là `123`, và phải tích
> **SQL Server Replication** lúc chọn tính năng.

## Bạn KHÔNG cần chuẩn bị gì thêm

Không phải tải mã nguồn, không cần tài khoản GitHub, không cần file database.
**Nhóm trưởng mang theo hết hôm lên lớp.** Việc của bạn ở nhà chỉ là cài phần mềm
và mở đường mạng.

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
5. **Install Rules**: có cảnh báo vàng về **Firewall** thì kệ nó, Next
6. **Feature Selection**: tick đúng **ba mục** sau

   ```
   [x] Database Engine Services
   [x] SQL Server Replication          <- QUAN TRỌNG, thiếu là hỏng cả đồ án
   [x] Full-Text and Semantic Extractions
   ```
   → Next

7. **Instance Configuration** — 📷 **CHỤP MÀN HÌNH NÀY**

   ```
   (o) Named instance:   KHO_B          <- gõ đúng chữ này, VIẾT HOA, có gạch dưới
       Instance ID:      KHO_B          (tự điền theo)
   ```
   → Next

8. **Server Configuration**

   Tìm dòng **SQL Server Agent**, đổi cột **Startup Type** từ `Manual` thành
   **`Automatic`**. Thiếu bước này thì phần nhân bản của đồ án không chạy.

   📷 **CHỤP MÀN HÌNH NÀY** → Next

9. **Database Engine Configuration** → tab **Server Configuration**

   ```
   (o) Mixed Mode (SQL Server authentication and Windows authentication)

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

Máy vừa cài xong thì **chỉ mình nó nói chuyện với nó**. Phải mở cổng TCP.

1. Bấm **Start** → gõ `powershell`
2. Ở kết quả **Windows PowerShell**, bấm **chuột phải** → **Run as administrator**
3. Windows hỏi *"Do you want to allow..."* → **Yes**
4. Cửa sổ mở ra phải có chữ **Administrator** trên thanh tiêu đề. Không có chữ đó
   thì làm lại — chạy thiếu quyền sẽ báo đỏ `Requested registry access is not allowed`.
5. Dán nguyên khối dưới đây vào rồi Enter — **đã điền sẵn đúng cho bạn**

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

> Báo đỏ *"Cannot find path ... MSSQL16.KHO_B"* nghĩa là **tên instance bạn đặt
> không phải `KHO_B`**. Mở **SQL Server Configuration Manager** xem tên thật. Sai
> tên thì phải gỡ ra cài lại cho đúng, vì script của nhóm gọi đích danh tên này.

---

## BƯỚC 6 — Mở MS DTC cho mạng

Đây là thứ cho phép **chuyển hàng giữa hai kho mà không mất hàng giữa chừng** —
phần quan trọng nhất của đồ án. Không mở thì demo chính không chạy được.

1. Bấm **Windows + R** → gõ `dcomcnfg` → **OK**
2. Bên trái bung lần lượt:
   **Component Services** → **Computers** → **My Computer** →
   **Distributed Transaction Coordinator**
3. Chuột phải **Local DTC** → **Properties**
4. Sang tab **Security**, tick đúng các ô sau:

   ```
   [x] Network DTC Access
   [x] Allow Inbound
   [x] Allow Outbound
   (o) No Authentication Required      <- chọn nút tròn NÀY
   [x] Enable XA Transactions
   ```

5. Bấm **OK** → nó hỏi khởi động lại dịch vụ → **Yes**

📷 **CHỤP MÀN HÌNH TAB SECURITY NÀY** — dùng cho báo cáo.

---

## BƯỚC 7 — Cài ZeroTier và vào mạng của nhóm

1. Vào `https://www.zerotier.com/download/` → tải bản **Windows** → cài (Next hết)
2. Nhìn khay đồng hồ góc dưới phải, tìm icon **ZeroTier** màu cam
   (không thấy thì bấm mũi tên `^` để bung ra)
3. **Chuột phải** vào icon đó → **Join New Network...**
4. Dán Network ID rồi bấm **Join**:

   ```
   a581878f7d00676e
   ```

5. Nhắn cho nhóm trưởng: *"mình join rồi, duyệt giúp"*
   Bạn ấy phải tích ô **Auth?** trên trang quản lý thì bạn mới vào được mạng.
6. Chờ khoảng 10 giây, chuột phải icon ZeroTier → **Show Networks**
   → dòng network phải ghi **OK** và có **Managed IP** dạng `10.91.x.x`

Lấy địa chỉ ảo bằng lệnh này cho chắc:

```powershell
ipconfig | Select-String -Context 0,4 "ZeroTier"
```

📷 **Chụp lại màn hình này.**

---

## BƯỚC 8 — Báo lại cho nhóm trưởng

Mở **SSMS** → Connect vào `.\KHO_B` (có dấu chấm và gạch chéo ngược) →
**New Query** → dán và chạy:

```sql
SELECT @@SERVERNAME                                        AS TenMayChu,
       CAST(SERVERPROPERTY('MachineName') AS NVARCHAR(60)) AS TenMayTinh,
       CAST(SERVERPROPERTY('Edition')     AS NVARCHAR(60)) AS PhienBan;
```

Gửi nhóm trưởng **ba thứ** — thiếu là hôm lên lớp phải ngồi hỏi lại, mất thời gian:

```
1. Ten may chu     (cot TenMayChu, vi du  LAPTOP-ABC\KHO_B)
2. IP ao ZeroTier  (dang 10.91.x.x, lay o buoc 7)
3. Anh chup cac buoc co dau may anh o tren
```

---

## NHỮNG LỖI HAY GẶP

| Hiện tượng | Nguyên nhân | Cách sửa |
|---|---|---|
| `Cannot find path ... MSSQL16.KHO_B` | Đặt sai tên instance | Xem tên thật trong Configuration Manager, sai thì cài lại |
| `Requested registry access is not allowed` | PowerShell chạy thiếu quyền | Đóng đi, mở lại bằng **Run as administrator** |
| `Login failed for user 'sa'` | Quên chọn Mixed Mode, hoặc mật khẩu khác `123` | Chạy `ALTER LOGIN sa ENABLE; ALTER LOGIN sa WITH PASSWORD='123';` |
| ZeroTier báo `ACCESS DENIED` | Nhóm trưởng chưa tích ô `Auth?` | Nhắn nhóm trưởng duyệt |
| Không thấy icon ZeroTier | Bị ẩn trong khay | Bấm mũi tên `^` cạnh đồng hồ |

---

## TÓM TẮT — TICK KHI XONG

- [ ] Ổ đĩa còn trên 10 GB
- [ ] Cài SQL Server 2022 **Developer**, instance tên **`KHO_B`**
- [ ] Có tick **SQL Server Replication** lúc chọn tính năng
- [ ] SQL Server Agent để **Automatic**
- [ ] **Mixed Mode**, mật khẩu `sa` là **`123`**
- [ ] Cài SSMS
- [ ] Chạy khối PowerShell mở cổng **1441** với quyền administrator
- [ ] Mở **MS DTC** cho mạng
- [ ] Cài ZeroTier, join `a581878f7d00676e`, báo nhóm trưởng duyệt
- [ ] Gửi lại **tên máy chủ** + **IP ảo** + ảnh chụp

> Tổng thời gian khoảng **1,5 tiếng**, phần lớn là ngồi chờ tải và cài.
> Làm xong ở nhà thì hôm lên lớp cả nhóm chỉ mất 30 phút là demo được.

---

## HÔM LÊN LỚP BẠN SẼ LÀM GÌ

Xem trước cho đỡ bỡ ngỡ. Nhóm trưởng đưa bạn file `KhoB.bak` và thư mục `SQL\`
ngay tại chỗ, bạn chỉ cần:

1. **Restore** `KhoB.bak` vào instance `KHO_B` của bạn
   (chuột phải **Databases** → **Restore Database** → **Device** → chọn file)
2. Mở `SQL\11_ChuyenSang3May.sql` mà nhóm trưởng đã điền sẵn thông số → bấm F5
3. Chạy một câu để chứng minh máy bạn nhìn được toàn hệ thống:

   ```sql
   SELECT * FROM dbo.v_TonKho_ToanHeThong;
   ```

4. Ngồi xem demo điều chuyển hàng giữa Kho A và kho của bạn

Không phải gõ thêm gì. Tổng cộng khoảng 15 phút.

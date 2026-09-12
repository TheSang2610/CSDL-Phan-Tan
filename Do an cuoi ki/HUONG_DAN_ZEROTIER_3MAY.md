# HƯỚNG DẪN MỤC 3.1 (VPN) VÀ 3.2 (LINK MẠNG GIỮA CÁC SERVER)

> Hai mục này trong đề cương sinh ra cho kịch bản nhiều máy. Tài liệu này chia
> làm **hai giai đoạn**: hôm nay làm một mình được tới đâu, và hôm lên lớp rủ
> hai bạn thì làm nốt phần nào.

---

# PHẦN A — LÀM NGAY HÔM NAY, MỘT MÌNH

## Bước A1. Mở đường TCP cho ba instance

Hiện tại ba instance chỉ nói chuyện qua **Shared Memory** — bộ nhớ chung trong
cùng một máy. Máy khác không với tới được. Phải bật TCP/IP trước.

1. Bấm **Start** → gõ `powershell`
2. Ở kết quả **Windows PowerShell**, bấm **chuột phải** → chọn **Run as administrator**
3. Nếu Windows hỏi "Do you want to allow..." → bấm **Yes**
4. Dán nguyên dòng này vào rồi bấm Enter:

```powershell
powershell -ExecutionPolicy Bypass -File "D:\CSDL PHAN TAN\Do an cuoi ki\BatTCPIP_VaFirewall.ps1"
```

Script tự làm hết: bật TCP/IP, gán cổng cố định, mở firewall, khởi động lại
dịch vụ. Mất khoảng 1 phút.

Kết quả mong đợi ở cuối:

```
KHO_A  ->  cổng 1440
KHO_B  ->  cổng 1441
KHO_C  ->  cổng 1442
```

📷 **Ảnh 3.2-1** — chụp toàn bộ cửa sổ PowerShell sau khi chạy xong
Lưu: `AnhChup\3.2_LinkMang\01_BatTCPIP_MoFirewall.png`

> Script **không đụng** tới database, Linked Server hay Replication. Muốn trả
> về như cũ thì xem phần ghi chú ở cuối file `.ps1`.

## Bước A2. Chụp cấu hình mạng trong Configuration Manager

1. Bấm **Windows + R** → gõ `SQLServerManager16.msc` → **OK**
2. Bên trái bung **SQL Server Network Configuration**
3. Bấm vào **Protocols for KHO_A** → bên phải thấy `TCP/IP` giờ là **Enabled**
4. Chuột phải **TCP/IP** → **Properties** → sang tab **IP Addresses** → kéo
   xuống cuối thấy **IPAll** với `TCP Port = 1440`

📷 **Ảnh 3.2-2** — chụp cửa sổ này
Lưu: `AnhChup\3.2_LinkMang\02_TCPIP_Port_KhoA.png`

## Bước A3. Cài ZeroTier

1. Vào `https://www.zerotier.com/download/`
2. Tải bản **Windows**, cài đặt (bấm Next hết, không cần đổi gì)

📷 **Ảnh 3.1-1** — chụp màn hình trình cài đặt
Lưu: `AnhChup\3.1_VPN_ZeroTier\01_CaiDat_ZeroTier.png`

## Bước A4. Tạo network riêng cho nhóm

1. Vào `https://my.zerotier.com/` → bấm **Login** → đăng nhập bằng Google
2. Bấm nút **Create A Network**
3. Một dòng mới hiện ra với **Network ID** dạng `abc1234567890def` (16 ký tự)
   → **chép lại mã này**, lát nữa gửi cho hai bạn trong nhóm
4. Bấm vào dòng đó để mở trang cấu hình network
5. Kéo xuống mục **Name**, đổi tên thành `CSDLPT_Nhom0x_QuanLyKho` cho dễ nhận

📷 **Ảnh 3.1-2** — chụp trang network, thấy rõ Network ID và tên
Lưu: `AnhChup\3.1_VPN_ZeroTier\02_TaoNetwork.png`

## Bước A5. Cho máy này tham gia network

1. Nhìn góc dưới phải màn hình (khay đồng hồ), tìm biểu tượng **ZeroTier**
   hình chữ ⊘ màu cam. Không thấy thì bấm mũi tên `^` để bung ra.
2. Chuột phải vào nó → chọn **Join New Network...**
3. Dán **Network ID** vừa chép → bấm **Join**
4. Quay lại trang `my.zerotier.com`, kéo xuống mục **Members**, thấy một dòng
   mới hiện ra với ô **Auth?** đang trống
5. ✅ **Tick vào ô Auth?** — không tick thì không vào được mạng
6. Chờ khoảng 10 giây, cột **Managed IPs** hiện IP ảo dạng `10.147.x.x`
   → **chép lại IP này**

📷 **Ảnh 3.1-3** — chụp trang Members, thấy máy đã được duyệt và có IP ảo
Lưu: `AnhChup\3.1_VPN_ZeroTier\03_Member_Da_Duyet.png`

## Bước A6. Kiểm chứng SQL Server chạy được qua đường VPN

Đây là ảnh **quan trọng nhất** của mục 3.2 — chứng minh CSDL thật sự đi qua
đường mạng ảo chứ không phải bộ nhớ chung.

> ⚠️ **Mọi địa chỉ `10.147.x.x` trong tài liệu này chỉ là ví dụ.** Không có máy nào
> mang sẵn địa chỉ đó. Gõ đại một địa chỉ ví dụ vào SSMS thì sẽ chờ khoảng 15 giây
> rồi hiện `Error: 258 — The wait operation timed out`. Lỗi đó **không phải hỏng
> cấu hình**, chỉ là đang gọi tới một máy không tồn tại.
>
> Lấy địa chỉ thật của máy mình bằng lệnh:
> ```powershell
> Get-NetIPAddress -AddressFamily IPv4 | Where-Object IPAddress -ne '127.0.0.1' |
>     Select-Object InterfaceAlias, IPAddress
> ```
> Dòng nào có `InterfaceAlias` chứa chữ **ZeroTier** thì đó là IP ảo. Chưa thấy
> dòng nào như vậy nghĩa là **chưa cài ZeroTier**, hãy quay lại bước A3.

> 💡 **Chưa kịp cài ZeroTier vẫn chụp được ảnh này.** Bằng chứng cần có là
> `net_transport = TCP` thay vì `Shared memory` — mà điều đó đúng với **mọi**
> địa chỉ IP, không riêng IP ảo. Cứ dùng IP mạng nhà của máy (dòng `Ethernet`
> hoặc `Wi-Fi`, dạng `192.168.x.x`) để chụp trước. Khi nào có ZeroTier thì chụp
> lại bằng IP ảo, ảnh mới đè lên ảnh cũ.

1. Mở **SSMS**
2. Bấm **Connect** → **Database Engine**
3. Ô **Server name** gõ **IP thật của máy mình** kèm cổng, dấu **phẩy** chứ không
   phải hai chấm:

   ```
   192.168.1.201,1440      <- ví dụ, thay bằng IP máy bạn
   ```
4. Authentication: **SQL Server Authentication**
   User: `sa`   Password: `123`
   ✅ tick **Trust Server Certificate**
5. Bấm **Connect**

Kết nối được nghĩa là gói tin đã chạy qua card mạng ảo ZeroTier để vào KHO_B.

6. Bấm **New Query** rồi chạy:

```sql
SELECT @@SERVERNAME                        AS MayChuDangKetNoi,
       DB_NAME()                           AS CSDL,
       net_transport                       AS GiaoThucKetNoi,
       local_net_address                   AS DiaChi_MayChu,
       local_tcp_port                      AS Cong,
       client_net_address                  AS DiaChi_MayKhach
FROM   sys.dm_exec_connections
WHERE  session_id = @@SPID;
```

Kết quả phải ra `net_transport = TCP` và `local_net_address` chính là địa chỉ bạn
vừa gõ ở ô Server name. **Đó là bằng chứng bằng số liệu**, không phải chỉ nói miệng.

📷 chụp cả ô Server name lẫn bảng kết quả
Lưu: `AnhChup\3.2_LinkMang\04_NetTransport_TCP.png`

> So sánh cho báo cáo: nếu nối theo `Mignon\KHO_B` như thường lệ thì
> `net_transport` sẽ là **Shared memory**. Nối qua IP ảo thì là **TCP**.
> Chụp cả hai để đặt cạnh nhau thì quá thuyết phục.

---

# PHẦN B — HÔM LÊN LỚP, RỦ HAI BẠN

Mục tiêu: có ảnh **ba máy thật** trong cùng một mạng ảo, và hai bạn kia truy
cập được vào CSDL trên máy bạn.

## Bước B1. Hai bạn cài ZeroTier và join

Gửi cho mỗi bạn đúng ba thứ:

```
1. Link tải:   https://www.zerotier.com/download/
2. Network ID: <mã 16 ký tự bạn tạo ở bước A4>
3. Hướng dẫn:  cài xong, chuột phải icon ZeroTier ở khay đồng hồ
               -> Join New Network -> dán Network ID -> Join
```

Sau đó **bạn** vào `my.zerotier.com` → mục **Members** → tick **Auth?** cho cả
hai máy mới.

📷 **Ảnh 3.1-4** — chụp trang Members lúc có **ba dòng**, mỗi dòng một IP ảo
Lưu: `AnhChup\3.1_VPN_ZeroTier\04_BaMay_TrongMangAo.png`

> Đây là ảnh đắt nhất của mục 3.1. Ba dòng = ba máy vật lý thật trong cùng một
> mạng riêng ảo.

## Bước B2. Kiểm tra ba máy thấy nhau

Trên máy bạn, mở PowerShell chạy (thay IP bằng IP ảo của hai bạn kia):

```powershell
Test-NetConnection 10.147.20.51 -InformationLevel Detailed
Test-NetConnection 10.147.20.77 -InformationLevel Detailed
```

📷 **Ảnh 3.2-4** — chụp kết quả `PingSucceeded : True`
Lưu: `AnhChup\3.2_LinkMang\04_BaMay_PingThau.png`

## Bước B3. Hai bạn nối vào CSDL trên máy bạn

Trên **máy của bạn thứ nhất**: cài SSMS (hoặc dùng máy có sẵn), Connect tới

```
<IP ảo máy BẠN>,1441      → KHO_B
sa / 123 , tick Trust Server Certificate
```

Bạn đó bung được Object Explorer thấy database `KhoB` → chụp.

Làm tương tự với **bạn thứ hai** và cổng `1442` → KHO_C.

📷 **Ảnh 3.2-5** và **3.2-6** — mỗi bạn một ảnh, thấy rõ ô Server name là IP ảo
Lưu: `AnhChup\3.2_LinkMang\05_BanA_NoiVao_KhoB.png`
     `AnhChup\3.2_LinkMang\06_BanB_NoiVao_KhoC.png`

## Bước B4. Chạy truy vấn phân tán từ máy bạn khác

Cho bạn đó chạy PHẦN 2 của file `09_TruyVanPhanTan_ThongKe.sql`. Kết quả vẫn
ra đủ 24 dòng của cả ba kho — nhưng lần này lệnh phát đi **từ một máy vật lý
khác**, đi qua VPN.

📷 **Ảnh 3.2-7**
Lưu: `AnhChup\3.2_LinkMang\07_TruyVanPhanTan_TuMayKhac.png`

---

# PHẦN C — VIẾT GÌ TRONG BÁO CÁO

## Mục 3.1 — Cài đặt VPN

Nội dung: lý do chọn ZeroTier (miễn phí, cài đặt đơn giản, tạo mạng LAN ảo
xuyên Internet nên ba chi nhánh ở ba tỉnh vẫn thấy nhau như cùng một phòng),
các bước cài, tạo network, duyệt thành viên, dải IP ảo được cấp.

Ảnh: 4 tấm của thư mục `3.1_VPN_ZeroTier`.

## Mục 3.2 — Tạo đường link kết nối mạng giữa các server

Nội dung: bật giao thức TCP/IP, gán cổng cố định cho từng instance, mở firewall,
mở MS DTC cho giao tác phân tán, kiểm chứng bằng `sys.dm_exec_connections`.

Bảng đưa vào báo cáo:

| Site | Instance | Cổng TCP | Vai trò |
|---|---|---|---|
| S1 | `MIGNON\KHO_A` | 1440 | Kho Trung tâm — Publisher + Distributor |
| S2 | `MIGNON\KHO_B` | 1441 | Kho Miền Bắc — Subscriber |
| S3 | `MIGNON\KHO_C` | 1442 | Kho Miền Nam — Subscriber |

Ảnh: 7 tấm của thư mục `3.2_LinkMang`.

## Câu trả lời nếu thầy hỏi "sao ba kho lại nằm trên một máy?"

Trả lời thẳng và đủ ý:

> Ba kho chạy trên **ba instance SQL Server độc lập** — ba dịch vụ Windows
> riêng biệt, ba SQL Agent riêng, ba database riêng, giao tiếp qua giao thức
> mạng TCP/IP với ba cổng khác nhau, không dùng chung bộ nhớ nào.
>
> Về phía phần mềm, đây **đúng là ba máy chủ CSDL phân tán**: Linked Server,
> Transactional Replication với Publisher/Distributor/Subscriber, và giao tác
> phân tán hai pha qua MS DTC đều hoạt động y hệt như khi đặt trên ba máy khác
> nhau.
>
> Nhóm đã kiểm chứng điều đó: khi cho hai máy khác tham gia mạng ảo ZeroTier,
> hai máy đó truy cập và chạy truy vấn phân tán trên hệ thống này bình thường,
> chỉ thay chuỗi kết nối từ tên instance sang `IP,cổng` — **không phải sửa một
> dòng mã nào** trong toàn bộ 10 script.
>
> Nguyên nhân gộp trên một máy là hạn chế phần cứng, không phải hạn chế thiết kế.

Lập luận này đứng vững vì nó **đúng sự thật** và có ảnh chứng minh.

---

# TÓM TẮT VIỆC CẦN LÀM

**Hôm nay (một mình, ~20 phút):**
- [ ] A1 — chạy `BatTCPIP_VaFirewall.ps1` bằng quyền Admin → 📷 1 ảnh
- [ ] A2 — chụp Configuration Manager → 📷 1 ảnh
- [ ] A3 — cài ZeroTier → 📷 1 ảnh
- [ ] A4 — tạo network, chép Network ID → 📷 1 ảnh
- [ ] A5 — join + duyệt máy mình → 📷 1 ảnh
- [ ] A6 — SSMS nối qua IP ảo + chạy câu kiểm chứng → 📷 1 ảnh

**Hôm lên lớp (rủ 2 bạn, ~15 phút):**
- [ ] B1 — hai bạn join network, bạn duyệt → 📷 1 ảnh (ảnh đắt nhất)
- [ ] B2 — ping thấu ba máy → 📷 1 ảnh
- [ ] B3 — hai bạn nối vào KHO_B và KHO_C → 📷 2 ảnh
- [ ] B4 — chạy truy vấn phân tán từ máy bạn → 📷 1 ảnh

**Gửi cho hai bạn trước hôm đó:** link tải ZeroTier + Network ID.

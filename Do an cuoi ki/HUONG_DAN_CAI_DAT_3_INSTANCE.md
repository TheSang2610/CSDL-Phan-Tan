# HƯỚNG DẪN CÀI ĐẶT 3 INSTANCE KHO_A / KHO_B / KHO_C
## Kèm danh sách ảnh cần chụp cho mục 3.3 và 3.4 của báo cáo

> Mở file này ra màn hình thứ hai (hoặc in ra) để vừa làm vừa đối chiếu.
> Chụp màn hình bằng **`Windows + Shift + S`** → vùng chọn → dán vào Paint → lưu.
>
> Lưu ảnh vào: `D:\CSDL PHAN TAN\Do an cuoi ki\AnhChup\3.3_CaiDat_SQLServer\`
> Đặt tên: `KhoA_01_Edition.png`, `KhoA_02_FeatureSelection.png`, …

---

## ❓ CHỤP BAO NHIÊU LÀ ĐỦ?

**Không cần chụp cả 15 màn hình cho cả 3 instance.** Trong wizard có 5–6 màn hình chỉ chạy
tự động (Global Rules, Install Rules, Feature Rules, Install Setup Files…) — chụp cũng không
chứng minh được điều gì.

| Instance | Chụp gì | Số ảnh |
|---|---|---|
| **KHO_A** | Chụp **đầy đủ** theo Phần 1 — làm phần minh họa chi tiết của báo cáo | ~10 |
| **KHO_B** | Chỉ 3 màn hình: Feature Selection, Instance Configuration, Complete | 3 |
| **KHO_C** | Chỉ 3 màn hình: Feature Selection, Instance Configuration, Complete | 3 |

Trong báo cáo viết một câu:

> *"Quy trình cài đặt được minh họa chi tiết qua instance KHO_A. Hai instance KHO_B và KHO_C
> thực hiện tương tự, chỉ khác tên instance và thư mục cài đặt — xem hình bên dưới."*

Đây là cách trình bày chuẩn trong tài liệu kỹ thuật: minh họa chi tiết một trường hợp đại diện,
các trường hợp còn lại nêu điểm khác biệt. Vừa đủ bằng chứng, vừa không lặp lại thừa thãi.

### 6 ảnh BẮT BUỘC phải có (thiếu là mất điểm)

| # | Màn hình | Chứng minh điều gì |
|---|---|---|
| 1 | **Feature Selection** (của cả 3 instance) | Đã cài **SQL Server Replication** — nền tảng của mục 3.6 |
| 2 | **Instance Configuration** của KHO_C | Bảng *Installed instances* có đủ 3 site |
| 3 | **Server Configuration** | **SQL Server Agent = Automatic** — nền tảng của mục 3.4 |
| 4 | **Complete** (của cả 3 instance) | Cài thành công, 5 dòng *Succeeded* |
| 5 | **SSMS Object Explorer** | Kết nối được đồng thời cả 3 instance |
| 6 | **Configuration Manager** | 3 service SQL + 3 service Agent đều *Running* |

---

# PHẦN 0 — GỠ INSTANCE KHO_A ĐANG CÓ

Chỉ làm phần này nếu bạn muốn cài lại KHO_A từ đầu để chụp ảnh.

Mở **PowerShell với quyền Administrator** (chuột phải nút Start → *Terminal (Admin)*), dán:

```powershell
& "C:\Program Files\Microsoft SQL Server\160\Setup Bootstrap\SQL2022\setup.exe" /Action=Uninstall /INSTANCENAME=KHO_A /FEATURES=SQLEngine,Replication /QUIET
```

Chạy xong kiểm tra bằng:

```powershell
Get-Service | Where-Object { $_.Name -like '*KHO_A*' }
```

Không ra dòng nào là đã gỡ sạch. Thư mục `D:\SQLServer\KhoA` có thể còn sót, xóa tay:

```powershell
Remove-Item 'D:\SQLServer\KhoA' -Recurse -Force
```

> **Lưu ý:** gỡ instance là **mất database `KhoA`** cùng dữ liệu thử. Không sao — chạy lại
> `SQL\01_TaoCSDL_KhoA.sql` là tạo lại đầy đủ trong vài giây.

---

# PHẦN 1 — CÀI INSTANCE KHO_A

Chạy `D:\SQL2022Media\setup.exe`.

## 1.1. SQL Server Installation Center

Bên trái chọn tab **Installation** → bấm dòng đầu tiên **New SQL Server standalone installation or add features to an existing installation**.

📷 **Ảnh 01** — `KhoA_01_InstallationCenter.png`

## 1.2. Edition

Chọn ô tròn **Specify a free edition** → dropdown chọn **Developer**.

📷 **Ảnh 02** — `KhoA_02_Edition.png`
> Ảnh này chứng minh dùng bản bản quyền hợp lệ, miễn phí cho mục đích học tập.

## 1.3. License Terms

Tick **I accept the license terms and Privacy Statement**.

📷 **Ảnh 03** — `KhoA_03_LicenseTerms.png`

## 1.4. Global Rules / Microsoft Update / Product Updates / Install Setup Files

Bốn màn hình này chạy tự động, cứ bấm **Next**. Ở *Microsoft Update* **không cần tick** gì.

📷 **Ảnh 04** — `KhoA_04_GlobalRules.png` (chụp màn hình Global Rules thấy các mục đều Passed)

## 1.5. Install Rules

Có thể hiện **Warning** ở dòng *Windows Firewall* — **bỏ qua, bấm Next**. Cảnh báo này chỉ nhắc
là phải mở cổng tường lửa nếu muốn truy cập từ máy khác, mình sẽ xử lý ở phần 5.

📷 **Ảnh 05** — `KhoA_05_InstallRules.png`

## 1.6. Azure Extension for SQL Server

⚠️ **BỎ TICK** ô **Azure Extension for SQL Server** ở góc trên bên trái.

Không bỏ tick thì nó bắt nhập tài khoản Azure và không bấm Next được.

📷 **Ảnh 06** — `KhoA_06_AzureExtension.png` (chụp sau khi đã bỏ tick)

## 1.7. Feature Selection ⭐ QUAN TRỌNG NHẤT

Tick **đúng 2 mục**:

- ☑ **Database Engine Services**
- ☑ **SQL Server Replication** ← **thiếu cái này là không làm được mục 3.6 báo cáo**

Ba ô đường dẫn ở dưới điền như sau:

```
Instance root directory        :  D:\SQLServer\KhoA
Shared feature directory       :  (bị khóa ở C, để nguyên)
Shared feature directory (x86) :  (bị khóa, để nguyên)
```

> Nhắc lại cho khỏi nhầm: **Instance root directory** là nơi chứa **dữ liệu thật** của kho —
> file `.mdf`, `.ldf`. Đây mới là thứ cần nằm ở ổ D.

📷 **Ảnh 07** — `KhoA_07_FeatureSelection.png`
> **Đây là ảnh thầy soi kỹ nhất.** Phải thấy rõ dòng *SQL Server Replication* đã được tick.

## 1.8. Feature Rules

Tự động chạy, bấm **Next**.

## 1.9. Instance Configuration

- Chọn ô tròn **Named instance**
- Gõ: **`KHO_A`**
- **Instance ID** tự đổi thành `KHO_A` — **để nguyên, đừng sửa tay**
- Dòng *SQL Server directory* sẽ thành `D:\SQLServer\KhoA\MSSQL16.KHO_A`

📷 **Ảnh 08** — `KhoA_08_InstanceConfiguration.png`
> Ảnh này chứng minh hệ thống có nhiều instance riêng biệt = nhiều site.

## 1.10. Server Configuration ⭐ DỄ BỎ SÓT

Tab **Service Accounts**, đổi cột *Startup Type*:

| Service | Startup Type |
|---|---|
| SQL Server Agent | `Manual` → **`Automatic`** ⚠️ |
| SQL Server Database Engine | `Automatic` (giữ nguyên) |
| SQL Server Browser | `Disabled` → **`Automatic`** ⚠️ |

> **Vì sao bắt buộc:**
> - **Agent** chạy các agent của Replication (Snapshot Agent, Log Reader, Distribution Agent).
>   Không bật thì mục 3.6 không chạy được, và mục 3.4 *"Kiểm tra dịch vụ Agent"* không có gì để chụp.
> - **Browser** giúp các instance tìm thấy nhau qua tên `MIGNON\KHO_B` thay vì phải nhớ số cổng.

Tab **Collation** để mặc định, không đổi. Cột trong CSDL đã khai báo `NVARCHAR` nên tiếng Việt vẫn đúng.

📷 **Ảnh 09** — `KhoA_09_ServerConfiguration.png` (thấy rõ Agent = Automatic)
📷 **Ảnh 10** — `KhoA_10_Collation.png`

## 1.11. Database Engine Configuration ⭐ QUAN TRỌNG

**Tab Server Configuration:**

- Chọn **Mixed Mode (SQL Server authentication and Windows authentication)**
- *Enter password* / *Confirm password*: **`Kho@2026`**
- Bấm nút **Add Current User**

> **Mật khẩu phải là `Kho@2026`, không được để `123`** — SQL Server bắt buộc tối thiểu 8 ký tự
> và có ít nhất 3 trong 4 nhóm (hoa/thường/số/ký tự đặc biệt). Dùng **cùng một mật khẩu cho cả
> 3 instance** để lát cấu hình Linked Server và Replication đỡ rối.
>
> **Vì sao cần Mixed Mode:** Linked Server và Replication giữa các instance sẽ dùng SQL login
> (`sa`) để xác thực. Chỉ có Windows Authentication thì cấu hình phức tạp hơn nhiều.

**Tab Data Directories:** kiểm tra tất cả đường dẫn phải bắt đầu bằng `D:\SQLServer\KhoA\`.
Nếu đúng rồi thì không cần sửa.

📷 **Ảnh 11** — `KhoA_11_DatabaseEngine_Auth.png` (thấy Mixed Mode + tài khoản admin)
📷 **Ảnh 12** — `KhoA_12_DataDirectories.png` (thấy đường dẫn ổ D)

## 1.12. Feature Configuration Rules

Tự động, bấm **Next**.

## 1.13. Ready to Install

Màn hình tổng hợp toàn bộ lựa chọn dưới dạng cây.

📷 **Ảnh 13** — `KhoA_13_ReadyToInstall.png`
> Ảnh này rất có giá trị: một tấm tóm tắt hết mọi cấu hình, dùng làm bằng chứng tổng hợp trong báo cáo.

Bấm **Install**. Chờ 10–20 phút.

## 1.14. Installation Progress

📷 **Ảnh 14** — `KhoA_14_Progress.png` (chụp lúc thanh tiến trình đang chạy)

## 1.15. Complete

📷 **Ảnh 15** — `KhoA_15_Complete.png`
> Phải thấy đủ 5 dòng **Succeeded**, trong đó có **SQL Server Replication**.

---

# PHẦN 2 — CÀI INSTANCE KHO_B

Chạy lại `D:\SQL2022Media\setup.exe`, làm **y hệt Phần 1**, chỉ đổi **đúng 2 chỗ**:

| Bước | KHO_A | **KHO_B** |
|---|---|---|
| 1.7 Instance root directory | `D:\SQLServer\KhoA` | **`D:\SQLServer\KhoB`** |
| 1.9 Named instance | `KHO_A` | **`KHO_B`** |

Mọi thứ khác giống hệt: bỏ tick Azure, tick **SQL Server Replication**, Agent + Browser =
**Automatic**, **Mixed Mode** + mật khẩu **`Kho@2026`**, **Add Current User**.

Chụp lại bộ ảnh tương tự, đặt tên `KhoB_01_...` → `KhoB_15_...`

> Ở bước 1.9 lần này bảng **Installed instances** phía dưới sẽ hiện `KHO_A`.
> 📷 Chụp kỹ ảnh này — nó chứng minh máy đang có **nhiều site** cùng tồn tại.

---

# PHẦN 3 — CÀI INSTANCE KHO_C

Giống hệt, đổi 2 chỗ:

| Bước | **KHO_C** |
|---|---|
| 1.7 Instance root directory | **`D:\SQLServer\KhoC`** |
| 1.9 Named instance | **`KHO_C`** |

Chụp `KhoC_01_...` → `KhoC_15_...`

> Ở bước 1.9 bảng *Installed instances* sẽ hiện **cả `KHO_A` và `KHO_B`**.
> 📷 **Ảnh quan trọng** — một tấm cho thấy đủ 3 site của hệ thống phân tán.

---

# PHẦN 4 — KIỂM TRA SAU KHI CÀI (mục 3.4 báo cáo)

## 4.1. SQL Server Configuration Manager

Gõ `SQLServerManager16.msc` vào ô Run (`Windows + R`).

Vào mục **SQL Server Services**, phải thấy:

```
SQL Server (KHO_A)          Running    Automatic
SQL Server (KHO_B)          Running    Automatic
SQL Server (KHO_C)          Running    Automatic
SQL Server Agent (KHO_A)    Running    Automatic     <- mục 3.4 cần đúng cái này
SQL Server Agent (KHO_B)    Running    Automatic
SQL Server Agent (KHO_C)    Running    Automatic
SQL Server Browser          Running    Automatic
```

📷 **Ảnh** → `AnhChup\3.4_DichVu_Agent\01_ConfigurationManager.png`

## 4.2. Bật TCP/IP cho cả 3 instance

Vẫn trong Configuration Manager → **SQL Server Network Configuration** → **Protocols for KHO_A**
→ chuột phải **TCP/IP** → **Enable**. Làm tương tự cho `KHO_B`, `KHO_C`.

Bật xong phải **khởi động lại 3 service SQL Server** (chuột phải → Restart).

📷 **Ảnh** → `AnhChup\3.4_DichVu_Agent\02_TCPIP_Enabled.png`

> **Vì sao cần:** Linked Server và Replication giao tiếp qua TCP/IP. Không bật thì 3 instance
> không nói chuyện được với nhau, mục 3.5 và 3.6 sẽ lỗi.

## 4.3. Bật MS DTC (cho giao tác phân tán)

`Windows + R` → gõ `dcomcnfg` → **Component Services → Computers → My Computer →
Distributed Transaction Coordinator → Local DTC** → chuột phải → **Properties** → tab **Security**:

- ☑ Network DTC Access
- ☑ Allow Inbound
- ☑ Allow Outbound
- Chọn **No Authentication Required**

Bấm OK, nó hỏi khởi động lại dịch vụ → **Yes**.

📷 **Ảnh** → `AnhChup\3.4_DichVu_Agent\03_MSDTC_Security.png`

> **Vì sao cần:** MS DTC là bộ điều phối giao tác phân tán, chạy giao thức **2 Phase Commit**.
> Không bật thì lệnh `BEGIN DISTRIBUTED TRANSACTION` trong nghiệp vụ điều chuyển sẽ báo lỗi.

## 4.4. Kết nối cả 3 instance bằng SSMS

Mở SSMS → Connect → lần lượt:

```
MIGNON\KHO_A     Windows Authentication
MIGNON\KHO_B
MIGNON\KHO_C
```

📷 **Ảnh** → `AnhChup\3.3_CaiDat_SQLServer\99_SSMS_3Instance.png`
> Một tấm Object Explorer thấy đủ 3 server — **ảnh đại diện cho toàn bộ hệ thống phân tán**,
> nên đưa lên đầu mục 3.3 của báo cáo.

---

# PHẦN 5 — CÀI ZEROTIER (mục 3.1 báo cáo)

Đề cương ghi rõ: *"Ở đây chúng ta sử dụng VPN miễn phí do ZeroTier cung cấp vì nó rất đơn giản
cài đặt. Hoặc cài Radmin."*

Phần này chỉ **thực sự cần** khi 3 site nằm trên **3 máy khác nhau** của 3 bạn trong nhóm.
Nếu cả 3 instance chạy trên một máy thì vẫn nên cài ZeroTier để có ảnh chụp cho mục 3.1 và
trình bày được phương án triển khai thật.

1. Tải tại `zerotier.com/download` → cài đặt
2. Đăng ký tài khoản miễn phí ở `my.zerotier.com`
3. Bấm **Create A Network** → được một **Network ID** (16 ký tự)
4. Trên mỗi máy: chuột phải icon ZeroTier ở khay hệ thống → **Join Network** → dán Network ID
5. Quay lại web, tick **Auth** cho từng máy để cho phép tham gia
6. Mỗi máy được cấp một IP dạng `10.147.x.x` — dùng IP này thay cho `MIGNON` khi tạo Linked Server

📷 Chụp vào `AnhChup\3.1_VPN_Mang\`:
- `01_ZeroTier_CreateNetwork.png` — màn hình tạo network, thấy Network ID
- `02_ZeroTier_Members.png` — danh sách máy đã join, thấy IP được cấp
- `03_ZeroTier_Client.png` — cửa sổ client trên máy, thấy trạng thái `OK`
- `04_Ping.png` — mở CMD ping từ máy này sang IP máy kia, thấy có phản hồi

---

# TÓM TẮT — BẢNG ĐỐI CHIẾU NHANH

| Cần điền | KHO_A | KHO_B | KHO_C |
|---|---|---|---|
| Named instance | `KHO_A` | `KHO_B` | `KHO_C` |
| Instance root directory | `D:\SQLServer\KhoA` | `D:\SQLServer\KhoB` | `D:\SQLServer\KhoC` |
| Edition | Developer | Developer | Developer |
| Azure Extension | bỏ tick | bỏ tick | bỏ tick |
| Features | Engine + **Replication** | Engine + **Replication** | Engine + **Replication** |
| SQL Server Agent | **Automatic** | **Automatic** | **Automatic** |
| SQL Server Browser | **Automatic** | **Automatic** | **Automatic** |
| Authentication | Mixed Mode | Mixed Mode | Mixed Mode |
| Mật khẩu `sa` | `Kho@2026` | `Kho@2026` | `Kho@2026` |

**Năm ảnh quan trọng nhất, thiếu là phải cài lại:**

1. Feature Selection — thấy đã tick **SQL Server Replication**
2. Instance Configuration của KHO_C — thấy bảng *Installed instances* có đủ 3 site
3. Server Configuration — thấy **SQL Server Agent = Automatic**
4. Complete — thấy 5 dòng **Succeeded**
5. SSMS Object Explorer — kết nối được cả 3 instance

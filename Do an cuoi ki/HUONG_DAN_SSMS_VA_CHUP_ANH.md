# HƯỚNG DẪN CÀI SSMS VÀ CHỤP ẢNH CHO BÁO CÁO

> SSMS = SQL Server Management Studio — phần mềm có giao diện để xem database,
> gõ lệnh SQL, xem Linked Server, tạo Publication. Không có nó thì mọi thứ chỉ
> chạy được bằng dòng lệnh, không có gì để chụp cho báo cáo.

---

# PHẦN 1 — CÀI LẠI SSMS

SSMS đã bị gỡ khi chạy script dọn dẹp. Cài lại như sau.

## Bước 1. Tải

Mở trình duyệt, vào địa chỉ:

```
https://aka.ms/ssmsfullsetup
```

Nó tự tải về file **`SSMS-Setup-ENU.exe`** (khoảng 700 MB, tải mất vài phút).

> Nếu link trên không chạy, vào Google gõ **"download SSMS"** rồi bấm vào trang
> `learn.microsoft.com` đầu tiên, tìm nút **"Free Download for SQL Server Management Studio"**.

## Bước 2. Cài

1. Mở file `SSMS-Setup-ENU.exe` vừa tải (thường nằm trong `Downloads`)
2. Cửa sổ cài đặt hiện ra, có dòng **Install Location**
3. ⚠️ Bấm nút **Change** (hoặc sửa trực tiếp ô đường dẫn) → đổi thành:
   ```
   D:\SSMS
   ```
4. Bấm nút **Install**
5. Chờ 10–15 phút
6. Xong bấm **Close**. Nếu nó hỏi khởi động lại máy thì bấm **Restart**

---

# PHẦN 2 — MỞ SSMS VÀ KẾT NỐI 3 SITE

## Bước 1. Mở SSMS

Bấm nút **Start** (biểu tượng Windows) → gõ `SSMS` → bấm vào **Microsoft SQL Server Management Studio**.

Lần đầu mở hơi lâu (30 giây tới 1 phút), kiên nhẫn chờ.

## Bước 2. Kết nối site thứ nhất

Cửa sổ **Connect to Server** tự hiện ra. Điền:

| Ô | Điền |
|---|---|
| Server type | `Database Engine` (có sẵn) |
| **Server name** | `Mignon\KHO_A` |
| Authentication | `Windows Authentication` (có sẵn) |

Bấm **Connect**.

> Nếu báo lỗi *"A network-related or instance-specific error..."* thì thử gõ
> `localhost\KHO_A` thay cho `Mignon\KHO_A`.

Kết nối xong, bên trái hiện khung **Object Explorer** với dòng `Mignon\KHO_A`.

## Bước 3. Kết nối thêm 2 site còn lại

Trong khung **Object Explorer** (bên trái), trên cùng có thanh công cụ nhỏ.
Bấm nút **Connect** (biểu tượng ổ cắm điện màu xanh) → chọn **Database Engine**.

Cửa sổ Connect to Server hiện ra lần nữa:
- Server name: `Mignon\KHO_B` → **Connect**

Làm lại lần nữa:
- Server name: `Mignon\KHO_C` → **Connect**

Kết quả: khung Object Explorer có **3 dòng**:

```
Mignon\KHO_A (SQL Server 16.0.1000.6 - ...)
Mignon\KHO_B (SQL Server 16.0.1000.6 - ...)
Mignon\KHO_C (SQL Server 16.0.1000.6 - ...)
```

📷 **CHỤP NGAY ẢNH NÀY** — đây là ảnh đại diện cho toàn bộ hệ thống phân tán.
Lưu vào `AnhChup\3.3_CaiDat_SQLServer\99_SSMS_3Instance.png`

---

# PHẦN 3 — CÁCH CHỤP MÀN HÌNH

Bấm ba phím cùng lúc: **`Windows` + `Shift` + `S`**

Màn hình mờ đi, con trỏ thành dấu cộng. Kéo chuột khoanh vùng muốn chụp
(khoanh **cả cửa sổ** chứ đừng cắt sát, để thấy thanh tiêu đề).

Thả chuột → ảnh đã vào bộ nhớ đệm. Góc dưới phải hiện thông báo nhỏ.

**Cách lưu thành file:**

1. Bấm **Start** → gõ `Paint` → mở **Paint**
2. Bấm `Ctrl + V` (dán)
3. Bấm `Ctrl + S` (lưu)
4. Chọn thư mục, đặt tên, bấm **Save**

> **Mẹo nhanh hơn:** bấm vào thông báo ở góc dưới phải ngay sau khi chụp,
> cửa sổ Snipping Tool mở ra, bấm biểu tượng đĩa mềm để lưu thẳng.

---

# PHẦN 4 — BA ẢNH CẦN CHỤP CHO MỤC 3.5 (LINKED SERVER)

Lưu hết vào: `D:\CSDL PHAN TAN\Do an cuoi ki\AnhChup\3.5_LinkedServer\`

## 📷 Ảnh 1 — Danh sách Linked Server

Trong **Object Explorer** bên trái, bấm vào dấu **`>`** (mũi tên nhỏ) để bung ra theo thứ tự:

```
Mignon\KHO_A
   └── Databases
   └── Security
   └── Server Objects          <-- bấm mũi tên mở cái này
          └── Backup Devices
          └── Endpoints
          └── Linked Servers   <-- bấm mũi tên mở cái này
                 └── Mignon\KHO_B      <-- phải thấy 2 dòng này
                 └── Mignon\KHO_C
```

Chụp cả khung Object Explorer đang mở tới đó.
Đặt tên: `01_DanhSachLinkedServer.png`

## 📷 Ảnh 2 — Cấu hình của một Linked Server

1. Chuột phải vào dòng **`Mignon\KHO_B`** (trong mục Linked Servers)
2. Chọn **Properties**
3. Cửa sổ mở ra, đang ở trang **General** → 📷 chụp → đặt tên `02_LinkedServer_General.png`
4. Bên trái cửa sổ đó bấm sang trang **Security** → 📷 chụp → `03_LinkedServer_Security.png`
5. Bấm **Cancel** để đóng (đừng bấm OK, tránh đổi nhầm cấu hình)

## 📷 Ảnh 3 — Truy vấn phân tán lấy dữ liệu từ 3 site

1. Bấm chuột trái **một lần** vào dòng `Mignon\KHO_A` trong Object Explorer
   (để chọn đúng server này)
2. Bấm nút **New Query** trên thanh công cụ trên cùng (biểu tượng tờ giấy có chữ)
3. Một ô soạn thảo trắng mở ra ở giữa màn hình
4. **Dán đoạn lệnh sau** vào ô đó:

```sql
SELECT MaKho, COUNT(*) AS SoDongTonKho, SUM(SoLuong) AS TongSoLuong
FROM KhoA.dbo.TonKho
GROUP BY MaKho
UNION ALL
SELECT MaKho, COUNT(*), SUM(SoLuong)
FROM [Mignon\KHO_B].KhoB.dbo.TonKho
GROUP BY MaKho
UNION ALL
SELECT MaKho, COUNT(*), SUM(SoLuong)
FROM [Mignon\KHO_C].KhoC.dbo.TonKho
GROUP BY MaKho
ORDER BY MaKho;
```

5. Bấm phím **`F5`** (hoặc nút **Execute** màu xanh lá trên thanh công cụ)
6. Bảng kết quả hiện ra phía dưới, phải ra **3 dòng**:

   ```
   MaKho    SoDongTonKho   TongSoLuong
   KHO_A         10           14070
   KHO_B          7            5131
   KHO_C          7            7003
   ```

7. 📷 **Chụp cả câu lệnh lẫn bảng kết quả trong MỘT ảnh** → `04_TruyVanPhanTan.png`

> **Đây là ảnh giá trị nhất của mục 3.5.** Nó chứng minh: đứng ở KHO_A mà đọc được
> dữ liệu của KHO_B và KHO_C qua Linked Server — tức là hệ thống thật sự phân tán
> và hoạt động.

---

# PHẦN 5 — HAI ẢNH CHO MỤC 3.4 (DỊCH VỤ AGENT)

Lưu vào `AnhChup\3.4_DichVu_Agent\`

## 📷 Ảnh 1 — SQL Server Configuration Manager

1. Bấm **`Windows` + `R`** (mở hộp Run)
2. Gõ: `SQLServerManager16.msc` → bấm **OK**
3. Cửa sổ mở ra, bên trái bấm vào **SQL Server Services**
4. Bên phải hiện danh sách dịch vụ, phải thấy:

   ```
   SQL Server (KHO_A)          Running    Automatic
   SQL Server (KHO_B)          Running    Automatic
   SQL Server (KHO_C)          Running    Automatic
   SQL Server Agent (KHO_A)    Running    Automatic
   SQL Server Agent (KHO_B)    Running    Automatic
   SQL Server Agent (KHO_C)    Running    Automatic
   SQL Server Browser          Running    Automatic
   ```

5. 📷 Chụp → `01_ConfigurationManager.png`

## 📷 Ảnh 2 — SQL Server Agent trong SSMS

Trong Object Explorer, kéo xuống dưới cùng của `Mignon\KHO_A`, thấy dòng
**SQL Server Agent**. Bấm mũi tên bung ra (phải bung được, không có dấu X đỏ).

📷 Chụp → `02_Agent_SSMS.png`

---

# TÓM TẮT VIỆC CẦN LÀM

- [ ] Tải và cài SSMS vào `D:\SSMS`
- [ ] Mở SSMS, kết nối cả 3 site → 📷 ảnh 3 instance
- [ ] Mục 3.5: 📷 4 ảnh (danh sách link, General, Security, truy vấn phân tán)
- [ ] Mục 3.4: 📷 2 ảnh (Configuration Manager, Agent trong SSMS)

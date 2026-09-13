# PHẦN MỀM ỨNG DỤNG CHO CÁC TRẠM

Phần **Bonus** của đề cương: *"Viết phần mềm ứng dụng cho các trạm theo thiết kế
nếu có thể"*.

Mỗi kho chạy **một bản** phần mềm này trên máy của mình, nối vào cơ sở dữ liệu
của chính kho đó. Người dùng ở kho nào chỉ thấy giao diện của kho ấy, nhưng vẫn
tra cứu được tồn kho toàn hệ thống và điều chuyển hàng sang kho khác.

---

## Kiến trúc

```
   Trình duyệt          Node.js + Express          SQL Server của site này
  (TẦNG TRÌNH BÀY)  ──HTTP──> (TẦNG NGHIỆP VỤ) ──TDS──> (TẦNG DỮ LIỆU)
                                                              │
                                              Linked Server ──┴──> hai site kia
```

Đúng mô hình ba tầng đã trình bày ở **Chương II mục 2.8** của báo cáo.

**Mọi thao tác ghi đều gọi thủ tục có sẵn trong cơ sở dữ liệu**, không viết câu
`INSERT` / `UPDATE` trực tiếp. Đây không phải sở thích lập trình mà là bắt buộc:
thủ tục mới là nơi đặt giao tác, khoá và kiểm tra tồn kho. Ứng dụng ghi thẳng vào
bảng sẽ đi vòng qua toàn bộ lớp bảo vệ đó — và vai trò `NhanVienKho` cũng không
có quyền ghi thẳng.

---

## Cài đặt

Chỉ làm **một lần**, trên máy nào chạy phần mềm thì làm ở máy đó.

```bash
cd "D:\CSDL PHAN TAN\Do an cuoi ki\UngDungWeb"
npm install
```

Trước đó phải chạy `SQL\12_ThuTuc_ChoUngDung.sql` **trên cả ba site** — file này
tạo bốn thủ tục mà phần mềm cần.

---

## Chạy

Bấm đúp file `.bat` tương ứng với kho của máy đó:

| Máy | File | Địa chỉ mở trình duyệt |
|---|---|---|
| Kho Trung tâm | `CHAY_KHO_A.bat` | `http://localhost:3001` |
| Kho Miền Bắc | `CHAY_KHO_B.bat` | `http://localhost:3002` |
| Kho Miền Nam | `CHAY_KHO_C.bat` | `http://localhost:3003` |

Ba cổng khác nhau để mở được cả ba trạm cùng lúc trên một máy khi diễn thử.

Hoặc gõ tay:

```bash
set SITE=KHO_B && node server.js
```

### Khi ba site nằm trên ba máy thật

Máy nào chạy trạm của mình thì `localhost` là đúng, không phải sửa gì. Chỉ khi
muốn nối tới máy khác mới cần:

```bash
set SITE=KHO_B && set DIACHI=10.91.229.51 && node server.js
```

---

## Các chức năng

| Mục | Nghiệp vụ đề bài yêu cầu | Gọi tới |
|---|---|---|
| Tổng quan | Xem mảnh dữ liệu của kho này, cảnh báo thiếu hàng | `sp_CanhBaoTonToiThieu` |
| Tồn kho toàn hệ thống | **Kiểm tra tồn kho toàn hệ thống** | `sp_TonKhoToanHeThong_Site` |
| Nhập kho | **Nhập vật tư tại Kho A** | `sp_NhapKho` |
| Xuất kho | **Xuất vật tư tại Kho B** | `sp_XuatKho` |
| Điều chuyển | **Điều chuyển vật tư giữa hai kho** | `sp_DieuChuyenVatTu` |
| Danh mục | **Đồng bộ danh mục vật tư** (xem bản sao tại chỗ) | bảng nhân bản |
| Lịch sử | Chứng từ gần đây của trạm | `sp_LichSuChungTu` |

---

## Màn hình đáng chiếu khi bảo vệ

Tab **Điều chuyển** có hai nút:

- **Điều chuyển** — chạy giao tác phân tán bình thường
- **Mô phỏng lỗi giữa chừng** — bật cờ `@GayLoiThuNghiem`, khiến giao tác hỏng
  **ngay sau khi kho nguồn đã bị trừ** nhưng **trước khi kho đích được cộng**

Cả hai nút đều tự chụp tồn kho ba site **trước** và **sau**, bày hai bảng cạnh
nhau. Với nút đỏ, hai bảng giống hệt nhau — đó chính là câu trả lời trực quan cho
yêu cầu *"nếu giao dịch thất bại giữa chừng thì dữ liệu phải được xử lý nhất
quán"*, mà không cần người xem đọc một dòng SQL nào.

---

## Không nối được cơ sở dữ liệu

Cửa sổ dòng lệnh in sẵn danh sách kiểm tra. Theo thứ tự hay gặp:

| Hiện tượng | Cách sửa |
|---|---|
| `Failed to connect` | Dịch vụ SQL Server của site chưa chạy, hoặc chưa mở cổng — chạy `BatTCPIP_VaFirewall.ps1` với quyền admin |
| `Login failed for user 'sa'` | Instance chưa bật Mixed Mode, hoặc mật khẩu khác `123` |
| `Could not find stored procedure 'sp_ThongTinSite'` | Chưa chạy `SQL\12_ThuTuc_ChoUngDung.sql` trên site này |
| Tab toàn hệ thống báo lỗi | Linked Server chưa thông, hoặc hai site kia đang tắt |

---

## Ghi chú về bảo mật

Mật khẩu `sa` để thẳng trong `cauhinh.js` là lựa chọn **của phòng thực hành**,
giống như phần còn lại của đồ án. Môi trường thật phải đặt trong biến môi trường
hoặc kho bí mật, và ứng dụng nên đăng nhập bằng tài khoản riêng chỉ có quyền
`EXECUTE` trên các thủ tục — đúng bốn vai trò đã thiết kế ở Chương II.

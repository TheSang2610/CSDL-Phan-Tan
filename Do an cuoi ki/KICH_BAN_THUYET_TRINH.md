# KỊCH BẢN THUYẾT TRÌNH — VỪA CHẠY VỪA NÓI

> Đồ án Cơ sở dữ liệu phân tán · Đề tài 2 — Quản lý kho vật tư đa chi nhánh · Nhóm 2
>
> Cầm tờ này khi demo. Mỗi mục có **lệnh chạy** và **lời nói** đi kèm.
> Chỗ in nghiêng là câu nói, cứ đọc gần đúng ý là được, không cần thuộc lòng.

---

## CHUẨN BỊ — làm trước khi thầy tới bàn

Ba việc này làm xong rồi mới gọi thầy. Đừng vừa làm vừa nói.

1. Ba máy bật ZeroTier, kiểm tra đủ ba dòng `Authorized` trên `central.zerotier.com`
2. Mỗi máy bấm đúp `CHAY_BAT_MSDTC.bat` → thấy `AuthenticationLevel : NoAuth`
3. Mỗi máy mở SSMS, chạy `SQL\11_ChuyenSang3May.sql`

Rồi đưa dữ liệu về mốc chuẩn — **chỉ máy Kho A chạy**:

```
SQL\07b_ResetDeChupLaiAnh.sql
```

Phải thấy `KHO_A 800` và `KHO_B 150`, `SoPhieuDieuChuyenConLai 0`.

Mở sẵn **ba cửa sổ SSMS** nối vào ba máy, để sẵn ở ba tab. Đừng để lúc thầy đứng
đó mới đi gõ mật khẩu.

---

# MÀN 1 — Chứng minh đây là ba máy thật *(1 phút)*

Mở cửa sổ nối `Mignon\KHO_A`, chạy:

```sql
USE KhoA;
SELECT 'KHO_A' AS Site,
       CAST(SERVERPROPERTY('MachineName') AS NVARCHAR(40)) COLLATE DATABASE_DEFAULT AS MayTinhThat,
       CAST(@@SERVERNAME AS NVARCHAR(60)) COLLATE DATABASE_DEFAULT AS Instance
UNION ALL
SELECT 'KHO_B', May COLLATE DATABASE_DEFAULT, Inst COLLATE DATABASE_DEFAULT
  FROM OPENQUERY([Mignon\KHO_B],
       'SELECT CAST(SERVERPROPERTY(''MachineName'') AS NVARCHAR(40)) May,
               CAST(@@SERVERNAME AS NVARCHAR(60)) Inst')
UNION ALL
SELECT 'KHO_C', May COLLATE DATABASE_DEFAULT, Inst COLLATE DATABASE_DEFAULT
  FROM OPENQUERY([Mignon\KHO_C],
       'SELECT CAST(SERVERPROPERTY(''MachineName'') AS NVARCHAR(40)) May,
               CAST(@@SERVERNAME AS NVARCHAR(60)) Inst');
```

**Nói:**

> *Thưa thầy, trước khi demo nghiệp vụ em xin chứng minh đây là ba máy vật lý
> riêng biệt chứ không phải ba thể hiện trên cùng một máy. Cột MayTinhThat cho
> ba tên máy khác nhau: Mignon là máy em, Admin-PC và GiaBinh là máy hai bạn,
> ba máy nối nhau qua mạng riêng ảo ZeroTier.*

Nếu thầy hỏi vì sao phải dùng `OPENQUERY`:

> *Nếu viết `@@SERVERNAME` thẳng trong truy vấn con thì hàm đó được tính tại máy
> gọi, ba dòng sẽ ra cùng một tên. `OPENQUERY` gửi nguyên chuỗi lệnh sang máy kia
> và cho hàm chạy ở bên đó, nên mới đọc được tên máy thật.*

---

# MÀN 2 — Trong suốt phân mảnh *(1 phút)*

```sql
SELECT 'KHO_A' Site, COUNT(*) SoDong, SUM(SoLuong) Tong FROM dbo.TonKho
UNION ALL
SELECT 'KHO_B', COUNT(*), SUM(SoLuong) FROM [Mignon\KHO_B].KhoB.dbo.TonKho
UNION ALL
SELECT 'KHO_C', COUNT(*), SUM(SoLuong) FROM [Mignon\KHO_C].KhoC.dbo.TonKho;
```

**Nói:**

> *Bảng TonKho được phân mảnh ngang theo mã kho: mỗi kho chỉ giữ dòng của chính
> mình. Câu lệnh này gom dữ liệu từ ba máy về một bảng duy nhất mà người viết câu
> truy vấn không cần biết dữ liệu nằm ở đâu — đó là trong suốt phân mảnh.*

Nếu thầy hỏi vì sao tên Linked Server vẫn là `Mignon\KHO_B` dù máy đó tên `Admin-PC`:

> *Linked Server tách làm hai phần: tên gọi và địa chỉ thật. Nhóm em giữ nguyên
> tên gọi cũ và chỉ đổi địa chỉ sang IP ảo, nhờ vậy toàn bộ mười tập lệnh viết từ
> trước chạy y nguyên, không sửa một dòng nào. Đó là trong suốt vị trí ở mức hạ tầng.*

---

# MÀN 3 — Nghiệp vụ đề bài: điều chuyển 50 sản phẩm *(3 phút)*

Mở `SQL\07_DieuChuyen_GiaoTacPhanTan.sql`, **bôi đen PHẦN 3** rồi bấm F5.

## Trước khi bấm — nói bối cảnh

> *Kho Miền Bắc báo thiếu bóng đèn LED: tồn hiện có 150, mức tồn tối thiểu là
> 200, thiếu đúng 50. Kho Trung tâm điều chuyển sang 50 đơn vị. Nghiệp vụ này
> đụng tới hai cơ sở dữ liệu nằm trên hai máy chủ khác nhau.*

## Sau khi bảng kết quả hiện ra

Chỉ vào hai bảng TRƯỚC và SAU:

> *Kho A đi từ 800 xuống 750, Kho B đi từ 150 lên 200. Tổng số hàng toàn hệ thống
> không đổi — rời kho nguồn bao nhiêu thì tới kho đích bấy nhiêu.*

Chỉ vào bảng phiếu điều chuyển:

> *Phiếu được ghi ở cả hai site trong cùng một giao tác. Không có chuyện một bên
> có phiếu còn bên kia không.*

---

# MÀN 4 — Kho nguồn không đủ hàng *(1 phút)*

**Bôi đen PHẦN 4** rồi bấm F5.

> *Bây giờ em thử chuyển 999.999 đơn vị, vượt xa số đang có. Thủ tục kiểm tra tồn
> kho trước khi trừ nên từ chối ngay, không site nào bị đụng tới. Bảng SAU giống
> hệt bảng TRƯỚC.*

Nhấn mạnh:

> *Đây là tầng bảo vệ thứ nhất — chặn từ đầu, chưa cần tới cơ chế quay lui.*

---

# MÀN 5 — LỖI GIỮA CHỪNG ⭐ *(3 phút)*

> Đây là thứ đề bài bắt buộc. Nếu chỉ còn thời gian cho một màn, chọn màn này.

**Bôi đen PHẦN 5** rồi bấm F5.

## Trước khi bấm — dựng tình huống

> *Màn này mô phỏng sự cố nguy hiểm nhất. Tham số GayLoiThuNghiem khiến thủ tục
> bung lỗi đúng vào thời điểm đã trừ kho nguồn và đã ghi phiếu, nhưng chưa cộng
> cho kho đích. Nếu không có cơ chế hai pha thì 50 đơn vị hàng sẽ bốc hơi: Kho A
> mất mà Kho B không nhận được.*

## Sau khi kết quả hiện ra

> *Giao tác đã bị huỷ. Tồn kho y nguyên, số phiếu không đổi. Hai nửa của giao tác
> nằm trên hai máy tính khác nhau nên không máy nào tự quay lui được — MS DTC
> đóng vai trọng tài hai pha: chỉ khi cả hai máy cùng báo sẵn sàng thì dữ liệu
> mới được ghi thật; một bên hỏng là cả hai bên cùng trở về trạng thái cũ.*

Câu chốt:

> *Đây chính là yêu cầu của đề bài: giao dịch thất bại giữa chừng thì dữ liệu vẫn
> nhất quán.*

---

# MÀN 6 — Tổng kết số học *(30 giây)*

**Bôi đen PHẦN 6** rồi bấm F5.

> *Tổng tồn kho toàn hệ thống trước và sau toàn bộ buổi demo bằng nhau. Mọi thao
> tác đều bảo toàn tổng lượng hàng.*

---

# MÀN 7 — Phần mềm ứng dụng *(2 phút, nếu còn giờ)*

Mở terminal trong thư mục `UngDungWeb`:

```
npm run dev
```

Vào `http://localhost:3001`, bấm tab **Điều chuyển**.

> *Đây là phần Bonus của đề cương — phần mềm cho các trạm. Mỗi kho chạy một bản
> trên máy của mình, nối vào cơ sở dữ liệu của chính kho đó.*

Bấm nút đỏ **Mô phỏng lỗi giữa chừng**:

> *Phần mềm tự chụp tồn kho ba site trước và sau rồi bày hai bảng cạnh nhau. Thầy
> thấy hai bảng giống hệt nhau — cùng một kết luận như màn 5, nhưng người dùng
> cuối không cần đọc dòng SQL nào.*

Nếu thầy hỏi vì sao không viết `INSERT` thẳng:

> *Phần mềm không viết câu INSERT hay UPDATE nào, mọi thao tác ghi đều gọi thủ
> tục có sẵn. Vì thủ tục mới là nơi đặt giao tác, khoá và kiểm tra tồn kho. Ghi
> thẳng vào bảng là đi vòng qua cả ba lớp bảo vệ đó, mà vai trò NhanVienKho cũng
> không có quyền ghi thẳng.*

---

# CÂU HỎI THẦY HAY HỎI

| Thầy hỏi | Trả lời |
|---|---|
| Vì sao chọn nhân bản danh mục mà không phân mảnh? | *Danh mục ghi 6 lần một ngày nhưng đọc ở mọi nơi mọi lúc. Tỷ lệ đọc trên ghi rất cao, đúng điều kiện lý tưởng để nhân bản.* |
| Vì sao chứng từ phải phân mảnh dẫn xuất? | *Bảng ChiTietNhap không có cột MaKho nên không tự chia ngang được, phải bám theo phiếu cha bằng phép nửa nối.* |
| Có phân mảnh dọc không? | *Nhóm em có cân nhắc nhưng không áp dụng. Bảng lớn nhất chỉ bốn cột, không có nhóm thuộc tính nào tách được theo tần suất truy cập. Dữ liệu ở đây phân tán theo dòng chứ không theo cột.* |
| Vì sao MS DTC để No Authentication? | *Vì ba máy không cùng domain nên không có cơ sở hạ tầng xác thực chung, không dùng được Mutual. Đây là lựa chọn của phòng thực hành; môi trường thật phải đưa máy vào domain và giữ Mutual.* |
| Mật khẩu `sa` là `123` có an toàn không? | *Không ạ. Đây là mật khẩu phòng thực hành để nhóm triển khai nhanh trên ba máy. Môi trường thật phải dùng tài khoản riêng chỉ có quyền EXECUTE trên các thủ tục, đúng bốn vai trò nhóm em đã thiết kế ở Chương II.* |
| Gặp khó khăn gì khi chuyển sang ba máy? | *Bốn lỗi mà mô hình ba thể hiện trên một máy không bao giờ gặp: MS DTC mặc định cấm giao tác qua mạng; mỗi máy có bộ đối chiếu mặc định khác nhau nên UNION ALL báo lỗi 451; tập lệnh tính site hiện tại sai sau khi USE master; và replication trỏ nhầm vào thể hiện nội bộ vì đặt tên Subscriber theo tên máy cục bộ.* |

Câu cuối là câu đáng giá nhất — nó cho thấy nhóm có chạy thật chứ không giả lập.

---

# KHI CÓ SỰ CỐ

| Hiện tượng | Xử lý |
|---|---|
| `Login timeout` khi gọi sang máy bạn | Máy đó ngủ hoặc ZeroTier tắt. Bảo bạn ấy mở lại, chờ 10 giây |
| `No transaction is active` | MS DTC máy nào đó còn `Mutual`. Chạy lại `CHAY_BAT_MSDTC.bat` |
| Lỗi 451 collation | Thiếu `COLLATE DATABASE_DEFAULT` trong câu `UNION ALL` |
| Số liệu lệch so với kịch bản | Chạy lại `07b_ResetDeChupLaiAnh.sql` |
| Mạng chết hẳn | Chuyển sang ba thể hiện trên máy mình. Nói thẳng với thầy là mạng lớp có vấn đề, vẫn demo đủ nghiệp vụ, chỉ mất phần ba máy vật lý |

Bình tĩnh. Có sự cố thì nói ra, đừng im lặng gõ lung tung.

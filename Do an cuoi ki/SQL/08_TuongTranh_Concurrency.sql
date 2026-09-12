/* ============================================================================
   ĐỒ ÁN CUỐI KỲ - CSDL PHÂN TÁN - QUẢN LÝ KHO VẬT TƯ ĐA CHI NHÁNH
   ----------------------------------------------------------------------------
   FILE 08 : TÌNH HUỐNG TƯƠNG TRANH (CONCURRENCY)

   Đáp ứng yêu cầu chung: "ít nhất 1 tình huống concurrency"
   Phục vụ mục báo cáo 3.7 - Thử các transaction.

   ----------------------------------------------------------------------------
   BỐN KỊCH BẢN
      C1  MẤT CẬP NHẬT (Lost Update)      - lỗi xảy ra khi KHÔNG khóa
      C2  KHÓA BI QUAN (Pessimistic)      - UPDLOCK + HOLDLOCK  -> hết lỗi
      C3  KHÓA LẠC QUAN (Optimistic)      - cột ROWVERSION      -> hết lỗi
      C4  KHÓA CHẾT (Deadlock)            - SQL Server tự chọn nạn nhân 1205

   ----------------------------------------------------------------------------
   KẾT QUẢ ĐÃ CHẠY THỬ THẬT TRÊN Mignon\KHO_B  (12/09/2026)

      C1  tồn cuối 150, đáng lẽ 50   -> mất đúng 100 đơn vị, đúng như dự đoán
      C2  phiên 2 bị chặn 13 giây, đọc được 150, tồn cuối 50  -> ĐÚNG
      C3  phiên 2 ghi được (150), phiên 1 @@ROWCOUNT = 0 -> bị từ chối, ĐÚNG
      C4  phiên 2 nhận Msg 1205 "chosen as the deadlock victim",
          phiên 1 hoàn tất, tổng hai dòng = 500 -> dữ liệu vẫn nhất quán

   ----------------------------------------------------------------------------
   ⚠️  CÁCH CHẠY - ĐỌC KỸ, KHÁC VỚI CÁC FILE TRƯỚC

   Tương tranh = HAI người cùng làm MỘT LÚC. Vì vậy phải mở HAI cửa sổ query,
   không thể bấm F5 một lần như các file khác.

   Bước 1. Trong SSMS, bấm chuột trái vào  Mignon\KHO_B  ở Object Explorer.
   Bước 2. Bấm  New Query  -> được cửa sổ thứ nhất, đặt tên trong đầu là PHIÊN 1.
   Bước 3. Bấm  New Query  lần nữa -> cửa sổ thứ hai = PHIÊN 2.
   Bước 4. Kéo hai cửa sổ nằm cạnh nhau:
              chuột phải lên tab của cửa sổ 2 -> New Vertical Tab Group
           Bây giờ nhìn thấy cả hai cùng lúc -> chụp một ảnh là đủ minh chứng.
   Bước 5. Copy khối [PHIÊN 1] dán vào cửa sổ trái,
           copy khối [PHIÊN 2] dán vào cửa sổ phải.
   Bước 6. Bấm F5 ở cửa sổ trái TRƯỚC, rồi trong vòng 15 giây bấm F5 cửa sổ phải.

   Mỗi khối đều tự chờ 15 giây nên không cần bấm nhanh, cứ thong thả.
   ============================================================================ */


/* ############################################################################
   PHẦN 0 - CHUẨN BỊ DỮ LIỆU DEMO
   Chạy khối này TRƯỚC MỖI KỊCH BẢN để trả tồn kho về mốc chuẩn 250.
   Chạy ở cửa sổ nào cũng được.
   ############################################################################ */
USE KhoB;
SET NOCOUNT ON;

UPDATE TonKho SET SoLuong = 250 WHERE MaKho = 'KHO_B' AND MaVT = 'VT001';
UPDATE TonKho SET SoLuong = 250 WHERE MaKho = 'KHO_B' AND MaVT = 'VT002';

SELECT N'--- MỐC CHUẨN TRƯỚC KHI THỬ ---' AS TrangThai, MaVT, SoLuong
FROM   TonKho
WHERE  MaKho = 'KHO_B' AND MaVT IN ('VT001','VT002');
GO


/* ############################################################################
   ############################################################################
   KỊCH BẢN C1 - MẤT CẬP NHẬT  (LOST UPDATE)
   ############################################################################

   Bối cảnh: kho VT001 còn 250. Hai nhân viên cùng lập phiếu xuất 100.
             Đúng ra phải còn  250 - 100 - 100 = 50.

   Cách viết SAI (rất phổ biến): đọc tồn vào biến, tính ngoài, rồi GHI ĐÈ.
        SELECT @Ton = SoLuong ...        -- đọc 250
        ... xử lý ...
        UPDATE SET SoLuong = @Ton - 100  -- ghi đè 150

   Cả hai phiên cùng đọc 250, cùng ghi đè 150. Lần ghi sau xoá sạch lần ghi
   trước -> hệ thống "quên" mất một phiếu xuất 100 -> tồn kho sai, hàng thất
   thoát mà sổ sách không biết.
   ############################################################################ */

-------------------------------------------------------------------------------
-- [C1 - PHIÊN 1]   dán vào CỬA SỔ TRÁI, bấm F5 trước
-------------------------------------------------------------------------------
USE KhoB;
SET NOCOUNT ON;
DECLARE @Ton INT, @Xuat INT = 100;

BEGIN TRANSACTION;

    -- ĐỌC: mức cô lập mặc định READ COMMITTED nhả khóa S ngay sau khi đọc xong
    SELECT @Ton = SoLuong
    FROM   TonKho
    WHERE  MaKho = 'KHO_B' AND MaVT = 'VT001';

    PRINT N'[PHIÊN 1] đọc được tồn = ' + CAST(@Ton AS NVARCHAR(10));
    PRINT N'[PHIÊN 1] đang xử lý phiếu... (chờ 15 giây)';

    WAITFOR DELAY '00:00:15';     -- mô phỏng thời gian nhân viên nhập liệu

    -- GHI ĐÈ bằng giá trị đã tính từ số liệu CŨ
    UPDATE TonKho
    SET    SoLuong = @Ton - @Xuat, NgayCapNhat = SYSDATETIME()
    WHERE  MaKho = 'KHO_B' AND MaVT = 'VT001';

    PRINT N'[PHIÊN 1] đã ghi tồn mới = ' + CAST(@Ton - @Xuat AS NVARCHAR(10));

COMMIT TRANSACTION;

SELECT N'C1 - SAU KHI CẢ HAI PHIÊN XONG' AS KetQua,
       SoLuong                            AS TonThucTe,
       50                                 AS TonDungPhaiLa,
       CASE WHEN SoLuong = 50 THEN N'ĐÚNG'
            ELSE N'✘ SAI - ĐÃ MẤT CẬP NHẬT ' + CAST(SoLuong - 50 AS NVARCHAR(10))
                 + N' đơn vị' END         AS NhanXet
FROM   TonKho WHERE MaKho = 'KHO_B' AND MaVT = 'VT001';
GO

-------------------------------------------------------------------------------
-- [C1 - PHIÊN 2]   dán vào CỬA SỔ PHẢI, bấm F5 NGAY SAU phiên 1
-------------------------------------------------------------------------------
USE KhoB;
SET NOCOUNT ON;
DECLARE @Ton2 INT, @Xuat2 INT = 100;

BEGIN TRANSACTION;

    SELECT @Ton2 = SoLuong
    FROM   TonKho
    WHERE  MaKho = 'KHO_B' AND MaVT = 'VT001';

    PRINT N'[PHIÊN 2] đọc được tồn = ' + CAST(@Ton2 AS NVARCHAR(10))
          + N'   <-- CŨNG ĐỌC ĐƯỢC, KHÔNG BỊ CHẶN';

    UPDATE TonKho
    SET    SoLuong = @Ton2 - @Xuat2, NgayCapNhat = SYSDATETIME()
    WHERE  MaKho = 'KHO_B' AND MaVT = 'VT001';

    PRINT N'[PHIÊN 2] đã ghi tồn mới = ' + CAST(@Ton2 - @Xuat2 AS NVARCHAR(10));

COMMIT TRANSACTION;
GO

/*  KẾT QUẢ MONG ĐỢI CỦA C1 -------------------------------------------------
    Phiên 2 chạy xong trước, ghi 150.
    Phiên 1 tỉnh dậy sau 15 giây, ghi đè 150 lần nữa.
    Tồn cuối cùng = 150, đáng lẽ phải là 50  ->  MẤT 100 ĐƠN VỊ.

    📷 Ảnh cần chụp: hai cửa sổ cạnh nhau, thấy cả hai đều in "đọc được tồn = 250"
       và bảng kết quả cuối in "✘ SAI - ĐÃ MẤT CẬP NHẬT 100 đơn vị".
       Lưu: AnhChup\3.7_KetQua_GiaoTac\04_C1_LostUpdate.png
    ------------------------------------------------------------------------ */


/* ############################################################################
   ############################################################################
   KỊCH BẢN C2 - KHẮC PHỤC BẰNG KHÓA BI QUAN (PESSIMISTIC LOCKING)
   ############################################################################

   Ý tưởng: ngay lúc ĐỌC đã tuyên bố "tôi sẽ sửa dòng này", buộc người đến sau
            phải xếp hàng chờ.

        WITH (UPDLOCK)   đặt khóa U ngay khi đọc, hai phiên không cùng giữ được
        WITH (HOLDLOCK)  giữ khóa đến hết giao tác, không nhả sớm

   Đây chính là cách thủ tục sp_XuatKho (file 04) và sp_DieuChuyenVatTu
   (file 07) đang dùng -> hệ thống của nhóm đã an toàn sẵn.

   ⚠️ Nhớ chạy lại PHẦN 0 để đưa tồn về 250 trước khi thử C2.
   ############################################################################ */

-------------------------------------------------------------------------------
-- [C2 - PHIÊN 1]   CỬA SỔ TRÁI, F5 trước
-------------------------------------------------------------------------------
USE KhoB;
SET NOCOUNT ON;
DECLARE @TonA INT, @XuatA INT = 100;

BEGIN TRANSACTION;

    -- KHÁC BIỆT DUY NHẤT SO VỚI C1 LÀ DÒNG WITH (UPDLOCK, HOLDLOCK)
    SELECT @TonA = SoLuong
    FROM   TonKho WITH (UPDLOCK, HOLDLOCK)
    WHERE  MaKho = 'KHO_B' AND MaVT = 'VT001';

    PRINT N'[PHIÊN 1] giữ khóa U, đọc được tồn = ' + CAST(@TonA AS NVARCHAR(10));

    WAITFOR DELAY '00:00:15';

    UPDATE TonKho
    SET    SoLuong = @TonA - @XuatA, NgayCapNhat = SYSDATETIME()
    WHERE  MaKho = 'KHO_B' AND MaVT = 'VT001';

    PRINT N'[PHIÊN 1] ghi tồn mới = ' + CAST(@TonA - @XuatA AS NVARCHAR(10))
          + N' rồi mới NHẢ KHÓA';

COMMIT TRANSACTION;
GO

-------------------------------------------------------------------------------
-- [C2 - PHIÊN 2]   CỬA SỔ PHẢI, F5 ngay sau
--   Cửa sổ này sẽ ĐỨNG IM khoảng 15 giây (SSMS hiện "Executing query...").
--   Đó chính là lúc nó đang bị CHẶN - hình ảnh đắt giá nhất của kịch bản này.
-------------------------------------------------------------------------------
USE KhoB;
SET NOCOUNT ON;
DECLARE @TonB INT, @XuatB INT = 100, @BatDau DATETIME2 = SYSDATETIME();

BEGIN TRANSACTION;

    SELECT @TonB = SoLuong
    FROM   TonKho WITH (UPDLOCK, HOLDLOCK)
    WHERE  MaKho = 'KHO_B' AND MaVT = 'VT001';

    PRINT N'[PHIÊN 2] ĐÃ PHẢI CHỜ '
          + CAST(DATEDIFF(SECOND, @BatDau, SYSDATETIME()) AS NVARCHAR(10))
          + N' giây mới vào được';
    PRINT N'[PHIÊN 2] đọc được tồn = ' + CAST(@TonB AS NVARCHAR(10))
          + N'   <-- SỐ MỚI NHẤT, KHÔNG PHẢI 250';

    UPDATE TonKho
    SET    SoLuong = @TonB - @XuatB, NgayCapNhat = SYSDATETIME()
    WHERE  MaKho = 'KHO_B' AND MaVT = 'VT001';

COMMIT TRANSACTION;

SELECT N'C2 - KHÓA BI QUAN' AS KichBan,
       SoLuong              AS TonThucTe,
       50                   AS TonDungPhaiLa,
       CASE WHEN SoLuong = 50 THEN N'✔ ĐÚNG - KHÓA ĐÃ CHỐNG ĐƯỢC MẤT CẬP NHẬT'
            ELSE N'✘ SAI' END AS NhanXet
FROM   TonKho WHERE MaKho = 'KHO_B' AND MaVT = 'VT001';
GO

/*  📷 Ảnh cần chụp cho C2:
       - Lúc phiên 2 đang đứng chờ: chụp cả hai cửa sổ, cửa sổ phải ghi
         "Executing query..." ở thanh trạng thái dưới cùng.
       - Sau khi xong: bảng "✔ ĐÚNG - KHÓA ĐÃ CHỐNG ĐƯỢC MẤT CẬP NHẬT" và
         dòng "[PHIÊN 2] ĐÃ PHẢI CHỜ 14 giây mới vào được".
       Lưu: AnhChup\3.7_KetQua_GiaoTac\05_C2_KhoaBiQuan.png
    ------------------------------------------------------------------------ */


/* ############################################################################
   ############################################################################
   KỊCH BẢN C3 - KHẮC PHỤC BẰNG KHÓA LẠC QUAN (OPTIMISTIC / ROWVERSION)
   ############################################################################

   Khóa bi quan an toàn nhưng bắt người khác phải chờ. Trong hệ PHÂN TÁN,
   chờ qua đường truyền mạng rất tốn kém. Cách thứ hai: KHÔNG khóa, cứ cho
   đọc thoải mái, nhưng lúc ghi thì KIỂM TRA XEM DÒNG CÓ BỊ AI SỬA CHƯA.

   Bảng TonKho có sẵn cột  RowVer ROWVERSION  - SQL Server TỰ ĐỘNG đổi giá trị
   cột này mỗi khi dòng bị sửa. Chỉ cần so sánh:

        UPDATE ... WHERE khóa chính = ... AND RowVer = @VerLucDoc

   Nếu @@ROWCOUNT = 0 nghĩa là RowVer đã đổi -> có người chen ngang -> từ chối
   ghi và báo người dùng làm lại. Đây là cách chuẩn cho ứng dụng web/phân tán.

   ⚠️ Nhớ chạy lại PHẦN 0 trước khi thử C3.
   ############################################################################ */

-------------------------------------------------------------------------------
-- [C3 - PHIÊN 1]   CỬA SỔ TRÁI, F5 trước  -> phiên này SẼ BỊ TỪ CHỐI
-------------------------------------------------------------------------------
USE KhoB;
SET NOCOUNT ON;
DECLARE @Ton1 INT, @Ver1 BINARY(8), @Xuat1 INT = 100;

-- ĐỌC: không đặt khóa gì cả, ghi nhớ thêm "dấu vân tay" của dòng
SELECT @Ton1 = SoLuong, @Ver1 = RowVer
FROM   TonKho
WHERE  MaKho = 'KHO_B' AND MaVT = 'VT001';

PRINT N'[PHIÊN 1] đọc tồn = ' + CAST(@Ton1 AS NVARCHAR(10))
      + N' , RowVer = ' + CONVERT(NVARCHAR(20), @Ver1, 1);

WAITFOR DELAY '00:00:15';

BEGIN TRANSACTION;

    UPDATE TonKho
    SET    SoLuong = @Ton1 - @Xuat1, NgayCapNhat = SYSDATETIME()
    WHERE  MaKho = 'KHO_B' AND MaVT = 'VT001'
      AND  RowVer = @Ver1;              -- <<< ĐIỀU KIỆN CHỐNG GHI ĐÈ

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION;
        PRINT N'';
        PRINT N'✘ [PHIÊN 1] BỊ TỪ CHỐI - XUNG ĐỘT TƯƠNG TRANH';
        PRINT N'   Dòng tồn kho đã bị phiên khác sửa trong lúc tôi đang xử lý.';
        PRINT N'   Hệ thống KHÔNG ghi đè. Người dùng phải tải lại số liệu mới.';

        SELECT N'C3 - PHIÊN 1 BỊ TỪ CHỐI' AS KetQua,
               @Ton1                       AS TonLucToiDoc,
               SoLuong                     AS TonHienTai,
               N'RowVer đã đổi -> phát hiện được xung đột' AS LyDo
        FROM   TonKho WHERE MaKho = 'KHO_B' AND MaVT = 'VT001';
    END
    ELSE
    BEGIN
        COMMIT TRANSACTION;
        PRINT N'✔ [PHIÊN 1] ghi thành công (không ai chen ngang)';
    END
GO

-------------------------------------------------------------------------------
-- [C3 - PHIÊN 2]   CỬA SỔ PHẢI, F5 ngay sau  -> phiên này ghi THÀNH CÔNG
-------------------------------------------------------------------------------
USE KhoB;
SET NOCOUNT ON;
DECLARE @Ton3 INT, @Ver3 BINARY(8), @Xuat3 INT = 100;

SELECT @Ton3 = SoLuong, @Ver3 = RowVer
FROM   TonKho
WHERE  MaKho = 'KHO_B' AND MaVT = 'VT001';

BEGIN TRANSACTION;
    UPDATE TonKho
    SET    SoLuong = @Ton3 - @Xuat3, NgayCapNhat = SYSDATETIME()
    WHERE  MaKho = 'KHO_B' AND MaVT = 'VT001'
      AND  RowVer = @Ver3;

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION;
        PRINT N'✘ [PHIÊN 2] bị từ chối';
    END
    ELSE
    BEGIN
        COMMIT TRANSACTION;
        PRINT N'✔ [PHIÊN 2] ghi thành công, tồn mới = '
              + CAST(@Ton3 - @Xuat3 AS NVARCHAR(10))
              + N'  -> RowVer của dòng vừa bị đổi';
    END
GO

/*  KẾT QUẢ MONG ĐỢI CỦA C3 -------------------------------------------------
    Phiên 2 ghi được, tồn còn 150, RowVer đổi.
    Phiên 1 tỉnh dậy, UPDATE không khớp RowVer cũ -> @@ROWCOUNT = 0 -> TỪ CHỐI.
    Tồn cuối = 150, KHÔNG bị ghi sai. Không mất dữ liệu âm thầm như C1.

    So sánh ba kịch bản:
        C1 không khóa       -> tồn 150 nhưng SAI, hệ thống không hề hay biết
        C2 khóa bi quan     -> tồn  50 ĐÚNG, phiên 2 phải chờ
        C3 khóa lạc quan    -> tồn 150 và hệ thống BÁO LỖI cho phiên 1 biết

    📷 Ảnh: AnhChup\3.7_KetQua_GiaoTac\06_C3_KhoaLacQuan_RowVersion.png
    ------------------------------------------------------------------------ */


/* ############################################################################
   ############################################################################
   KỊCH BẢN C4 - KHÓA CHẾT (DEADLOCK) VÀ CƠ CHẾ TỰ GỠ CỦA SQL SERVER
   ############################################################################

   Hai giao tác khóa hai tài nguyên theo THỨ TỰ NGƯỢC NHAU:

        PHIÊN 1:  khóa VT001  ->  rồi đòi VT002
        PHIÊN 2:  khóa VT002  ->  rồi đòi VT001

   Mỗi bên giữ thứ bên kia cần -> chờ nhau vĩnh viễn. Bộ Lock Monitor của
   SQL Server quét định kỳ (mặc định 5 giây), phát hiện vòng tròn chờ và
   CHỌN MỘT NẠN NHÂN (transaction có chi phí rollback thấp hơn), huỷ nó bằng

        Msg 1205 - Transaction was deadlocked on lock resources ... rerun

   Giao tác nạn nhân được rollback TOÀN BỘ, giao tác còn lại chạy tiếp bình
   thường -> CSDL vẫn nhất quán, không cần con người can thiệp.

   ⚠️ Nhớ chạy lại PHẦN 0 trước khi thử C4.
   ############################################################################ */

-------------------------------------------------------------------------------
-- [C4 - PHIÊN 1]   CỬA SỔ TRÁI, F5 trước
--                  thứ tự khóa:  VT001  ->  VT002
-------------------------------------------------------------------------------
USE KhoB;
SET NOCOUNT ON;

BEGIN TRY
    BEGIN TRANSACTION;

        UPDATE TonKho SET SoLuong = SoLuong - 10
        WHERE  MaKho = 'KHO_B' AND MaVT = 'VT001';
        PRINT N'[PHIÊN 1] đã khóa VT001, đang chờ 10 giây...';

        WAITFOR DELAY '00:00:10';

        UPDATE TonKho SET SoLuong = SoLuong + 10
        WHERE  MaKho = 'KHO_B' AND MaVT = 'VT002';
        PRINT N'[PHIÊN 1] đã khóa thêm VT002';

    COMMIT TRANSACTION;
    PRINT N'✔ [PHIÊN 1] HOÀN TẤT - tôi là bên SỐNG SÓT';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    PRINT N'';
    PRINT N'✘ [PHIÊN 1] BỊ CHỌN LÀM NẠN NHÂN DEADLOCK';
    PRINT N'   Số hiệu lỗi : ' + CAST(ERROR_NUMBER() AS NVARCHAR(10))
          + CASE WHEN ERROR_NUMBER() = 1205 THEN N'   (đúng mã deadlock)' ELSE N'' END;
    PRINT N'   Nội dung    : ' + ERROR_MESSAGE();
    PRINT N'   -> Giao tác đã được ROLLBACK sạch, dữ liệu vẫn nhất quán.';
END CATCH
GO

-------------------------------------------------------------------------------
-- [C4 - PHIÊN 2]   CỬA SỔ PHẢI, F5 ngay sau
--                  thứ tự khóa NGƯỢC LẠI:  VT002  ->  VT001
-------------------------------------------------------------------------------
USE KhoB;
SET NOCOUNT ON;

BEGIN TRY
    BEGIN TRANSACTION;

        UPDATE TonKho SET SoLuong = SoLuong - 10
        WHERE  MaKho = 'KHO_B' AND MaVT = 'VT002';
        PRINT N'[PHIÊN 2] đã khóa VT002, đang chờ 10 giây...';

        WAITFOR DELAY '00:00:10';

        UPDATE TonKho SET SoLuong = SoLuong + 10
        WHERE  MaKho = 'KHO_B' AND MaVT = 'VT001';
        PRINT N'[PHIÊN 2] đã khóa thêm VT001';

    COMMIT TRANSACTION;
    PRINT N'✔ [PHIÊN 2] HOÀN TẤT - tôi là bên SỐNG SÓT';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    PRINT N'';
    PRINT N'✘ [PHIÊN 2] BỊ CHỌN LÀM NẠN NHÂN DEADLOCK';
    PRINT N'   Số hiệu lỗi : ' + CAST(ERROR_NUMBER() AS NVARCHAR(10))
          + CASE WHEN ERROR_NUMBER() = 1205 THEN N'   (đúng mã deadlock)' ELSE N'' END;
    PRINT N'   Nội dung    : ' + ERROR_MESSAGE();
    PRINT N'   -> Giao tác đã được ROLLBACK sạch, dữ liệu vẫn nhất quán.';
END CATCH
GO

-------------------------------------------------------------------------------
-- [C4 - KIỂM CHỨNG]  chạy sau khi cả hai phiên đã dừng
-------------------------------------------------------------------------------
USE KhoB;
SELECT N'C4 - SAU DEADLOCK' AS KichBan, MaVT, SoLuong,
       N'Tổng hai dòng phải = 500 vì hai lệnh -10 và +10 bù trừ nhau' AS GhiChu
FROM   TonKho WHERE MaKho = 'KHO_B' AND MaVT IN ('VT001','VT002');

SELECT N'TỔNG KIỂM TRA' AS Muc,
       SUM(SoLuong)     AS TongHaiDong,
       CASE WHEN SUM(SoLuong) = 500
            THEN N'✔ NHẤT QUÁN - deadlock đã được gỡ mà không hỏng dữ liệu'
            ELSE N'✘ Cần chạy lại PHẦN 0 rồi thử lại' END AS NhanXet
FROM   TonKho WHERE MaKho = 'KHO_B' AND MaVT IN ('VT001','VT002');
GO

/*  📷 Ảnh: chụp hai cửa sổ cạnh nhau, một bên in "✔ HOÀN TẤT - tôi là bên
       SỐNG SÓT", bên kia in "✘ BỊ CHỌN LÀM NẠN NHÂN DEADLOCK ... 1205".
       Lưu: AnhChup\3.7_KetQua_GiaoTac\07_C4_Deadlock_1205.png
    ------------------------------------------------------------------------ */


/* ############################################################################
   PHẦN 5 - QUAN SÁT KHÓA ĐANG TỒN TẠI  (ảnh phụ, rất thuyết phục)

   Trong lúc kịch bản C2 đang chạy (phiên 2 đứng chờ), mở CỬA SỔ THỨ BA và
   chạy khối này. Nó chỉ thẳng ra phiên nào đang chặn phiên nào.
   ############################################################################ */
USE KhoB;
SET NOCOUNT ON;

SELECT  r.session_id          AS PhienBiChan,
        r.blocking_session_id AS PhienDangChan,
        r.wait_type           AS LoaiCho,
        r.wait_time / 1000.0  AS DaCho_Giay,
        r.wait_resource       AS TaiNguyenTranhChap,
        LEFT(t.text, 80)      AS CauLenh
FROM    sys.dm_exec_requests r
CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
WHERE   r.blocking_session_id <> 0;

SELECT  l.request_session_id AS Phien,
        l.resource_type      AS LoaiTaiNguyen,
        l.request_mode       AS CheDoKhoa,
        l.request_status     AS TrangThai,
        OBJECT_NAME(p.object_id) AS Bang
FROM    sys.dm_tran_locks l
LEFT JOIN sys.partitions p ON p.hobt_id = l.resource_associated_entity_id
WHERE   l.resource_database_id = DB_ID('KhoB')
  AND   l.resource_type IN ('KEY','PAGE','OBJECT')
ORDER BY l.request_session_id, l.resource_type;
GO

/*  📷 Ảnh: AnhChup\3.7_KetQua_GiaoTac\08_QuanSat_Khoa_Blocking.png
       Cột PhienDangChan chỉ ra đúng session_id của phiên 1 -> bằng chứng
       cơ chế khóa của SQL Server đang làm việc.
    ------------------------------------------------------------------------ */


/* ############################################################################
   PHẦN 6 - TRẢ DỮ LIỆU VỀ TRẠNG THÁI BAN ĐẦU SAU KHI DEMO XONG
   ############################################################################ */
USE KhoB;
SET NOCOUNT ON;

/* 250 và 140 là số liệu của KHO_B ngay TRƯỚC khi demo tương tranh, khớp với
   các ảnh đã chụp ở kịch bản T2/T3 của file 07. Trả về đúng hai số này để
   toàn bộ ảnh minh chứng trong báo cáo nhất quán với nhau.                  */
UPDATE TonKho SET SoLuong = 250 WHERE MaKho = 'KHO_B' AND MaVT = 'VT001';
UPDATE TonKho SET SoLuong = 140 WHERE MaKho = 'KHO_B' AND MaVT = 'VT002';

SELECT N'ĐÃ TRẢ VỀ SỐ LIỆU TRƯỚC DEMO' AS TrangThai, MaVT, SoLuong
FROM   TonKho WHERE MaKho = 'KHO_B' AND MaVT IN ('VT001','VT002');
GO


/* ============================================================================
   TỔNG KẾT CHO BÁO CÁO - BẢNG SO SÁNH BỐN KỊCH BẢN

   ┌──────┬────────────────────┬────────────┬──────────────────────────────┐
   │ Mã   │ Kịch bản           │ Kết quả    │ Ý nghĩa                      │
   ├──────┼────────────────────┼────────────┼──────────────────────────────┤
   │ C1   │ Không khóa         │ tồn 150 ✘  │ Mất cập nhật, sai âm thầm    │
   │ C2   │ UPDLOCK+HOLDLOCK   │ tồn  50 ✔  │ Đúng, phiên sau phải chờ     │
   │ C3   │ ROWVERSION         │ tồn 150 ✔  │ Đúng, báo lỗi cho phiên thua │
   │ C4   │ Deadlock 2 chiều   │ tổng 500 ✔ │ SQL tự gỡ bằng Msg 1205      │
   └──────┴────────────────────┴────────────┴──────────────────────────────┘

   KẾT LUẬN ĐƯA VÀO BÁO CÁO
     Hệ thống của nhóm chọn KHÓA BI QUAN (C2) cho các thao tác trong cùng một
     site - sp_XuatKho và sp_DieuChuyenVatTu đều dùng WITH (UPDLOCK, HOLDLOCK).
     Lý do: thao tác kho ngắn, tranh chấp ít, khóa bi quan cho kết quả đúng
     tuyệt đối mà không bắt người dùng nhập lại phiếu.

     Cột RowVer (C3) được giữ trong bảng TonKho để dành cho tầng ứng dụng
     web/desktop sau này, nơi một màn hình có thể mở hàng phút trước khi bấm
     Lưu - lúc đó khóa bi quan sẽ chặn cả hệ thống quá lâu.

     Deadlock (C4) được SQL Server tự xử lý; phía ứng dụng chỉ cần bắt lỗi
     1205 và thử lại giao tác là đủ.
   ============================================================================ */

/* ============================================================================
   ĐỒ ÁN CUỐI KỲ - CSDL PHÂN TÁN - QUẢN LÝ KHO VẬT TƯ ĐA CHI NHÁNH
   ----------------------------------------------------------------------------
   FILE 04 : THỦ TỤC NGHIỆP VỤ CỤC BỘ TẠI MỖI SITE

   CHẠY TẠI : CẢ BA instance - MIGNON\KHO_A , MIGNON\KHO_B , MIGNON\KHO_C
              (nhớ chọn đúng database KhoA / KhoB / KhoC trước khi chạy)

   Script này KHÔNG cần sửa gì giữa 3 site. Thủ tục tự nhận biết mình đang
   đứng ở kho nào thông qua hàm dbo.fn_MaKhoHienTai() - đây chính là biểu hiện
   của TÍNH TRONG SUỐT PHÂN MẢNH (fragmentation transparency): ứng dụng viết
   một lần, chạy giống nhau ở mọi mảnh.

   Nghiệp vụ cài đặt:
     F1 - Nhập vật tư tại kho          -> sp_NhapKho
     F2 - Xuất vật tư tại kho          -> sp_XuatKho
     F3 - Tra cứu tồn kho tại chỗ      -> sp_TraCuuTonKho
     F7 - Cảnh báo dưới mức tồn tối thiểu -> sp_CanhBaoTonToiThieu
   ============================================================================ */

SET NOCOUNT ON;
GO

/* ----------------------------------------------------------------------------
   1. HÀM NHẬN DIỆN SITE

   Suy ra mã kho từ TÊN DATABASE: KhoA -> KHO_A , KhoB -> KHO_B , KhoC -> KHO_C
   Nhờ vậy một file script duy nhất chạy được trên cả ba site.
   ---------------------------------------------------------------------------- */
IF OBJECT_ID('dbo.fn_MaKhoHienTai', 'FN') IS NOT NULL DROP FUNCTION dbo.fn_MaKhoHienTai;
GO
CREATE FUNCTION dbo.fn_MaKhoHienTai() RETURNS CHAR(5)
AS
BEGIN
    RETURN 'KHO_' + UPPER(RIGHT(DB_NAME(), 1));
END
GO

/* ----------------------------------------------------------------------------
   2. KIỂU BẢNG DÙNG LÀM THAM SỐ (Table-Valued Parameter)

   Cho phép truyền NHIỀU dòng chi tiết vật tư vào thủ tục trong MỘT lần gọi,
   thay vì gọi thủ tục nhiều lần - giảm số vòng giao tiếp, quan trọng trong
   môi trường phân tán.
   ---------------------------------------------------------------------------- */
IF TYPE_ID('dbo.ChiTietVatTu_Type') IS NOT NULL DROP TYPE dbo.ChiTietVatTu_Type;
GO
CREATE TYPE dbo.ChiTietVatTu_Type AS TABLE (
    MaVT    CHAR(5)       NOT NULL PRIMARY KEY,
    SoLuong INT           NOT NULL,
    DonGia  DECIMAL(14,0) NOT NULL
);
GO

/* ----------------------------------------------------------------------------
   3. HÀM SINH MÃ CHỨNG TỪ

   Mã có nhúng KÝ TỰ KHO (PNA0001 / PNB0001 / PNC0001) để khóa chính không bao
   giờ đụng nhau giữa 3 site - kỹ thuật bắt buộc khi khóa được sinh độc lập ở
   nhiều nơi trong hệ phân tán.
   ---------------------------------------------------------------------------- */
IF OBJECT_ID('dbo.fn_MaPhieuKeTiep', 'FN') IS NOT NULL DROP FUNCTION dbo.fn_MaPhieuKeTiep;
GO
CREATE FUNCTION dbo.fn_MaPhieuKeTiep(@Loai CHAR(2))   -- 'PN' hoặc 'PX'
RETURNS CHAR(7)
AS
BEGIN
    DECLARE @KyTuKho CHAR(1) = UPPER(RIGHT(DB_NAME(), 1));
    DECLARE @TienTo  CHAR(3) = @Loai + @KyTuKho;
    DECLARE @So      INT;

    IF @Loai = 'PN'
        SELECT @So = ISNULL(MAX(CAST(RIGHT(MaPN, 4) AS INT)), 0) + 1
        FROM PhieuNhap WHERE MaPN LIKE @TienTo + '%';
    ELSE
        SELECT @So = ISNULL(MAX(CAST(RIGHT(MaPX, 4) AS INT)), 0) + 1
        FROM PhieuXuat WHERE MaPX LIKE @TienTo + '%';

    RETURN @TienTo + RIGHT('0000' + CAST(@So AS VARCHAR(4)), 4);
END
GO

/* ----------------------------------------------------------------------------
   4. F1 - NHẬP VẬT TƯ VÀO KHO

   Giao tác CỤC BỘ (chỉ đụng dữ liệu của site này) nhưng vẫn phải bảo đảm
   TÍNH NGUYÊN TỬ: hoặc ghi được cả phiếu + chi tiết + cập nhật tồn, hoặc
   không ghi gì cả.
   ---------------------------------------------------------------------------- */
IF OBJECT_ID('dbo.sp_NhapKho', 'P') IS NOT NULL DROP PROCEDURE dbo.sp_NhapKho;
GO
CREATE PROCEDURE dbo.sp_NhapKho
    @MaNCC    CHAR(5),
    @NguoiLap NVARCHAR(50),
    @ChiTiet  dbo.ChiTietVatTu_Type READONLY,
    @MaPN     CHAR(7) = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;          -- gặp lỗi là rollback ngay, không để giao tác treo

    DECLARE @MaKho CHAR(5) = dbo.fn_MaKhoHienTai();

    IF NOT EXISTS (SELECT 1 FROM @ChiTiet)
    BEGIN
        RAISERROR (N'Phiếu nhập phải có ít nhất một dòng chi tiết.', 16, 1);
        RETURN;
    END

    IF EXISTS (SELECT 1 FROM @ChiTiet WHERE SoLuong <= 0)
    BEGIN
        RAISERROR (N'Số lượng nhập phải lớn hơn 0.', 16, 1);
        RETURN;
    END

    IF EXISTS (SELECT 1 FROM @ChiTiet c WHERE NOT EXISTS
              (SELECT 1 FROM VatTu v WHERE v.MaVT = c.MaVT))
    BEGIN
        RAISERROR (N'Có mã vật tư không tồn tại trong danh mục.', 16, 1);
        RETURN;
    END

    BEGIN TRY
        BEGIN TRANSACTION;

            SET @MaPN = dbo.fn_MaPhieuKeTiep('PN');

            INSERT INTO PhieuNhap (MaPN, MaKho, MaNCC, NgayNhap, NguoiLap, TrangThai)
            VALUES (@MaPN, @MaKho, @MaNCC, SYSDATETIME(), @NguoiLap, 'HOAN_TAT');

            INSERT INTO ChiTietNhap (MaPN, MaVT, SoLuong, DonGia)
            SELECT @MaPN, MaVT, SoLuong, DonGia FROM @ChiTiet;

            -- Cộng tồn kho: vật tư đã có thì cộng dồn, chưa có thì tạo dòng mới
            MERGE TonKho AS t
            USING (SELECT MaVT, SoLuong FROM @ChiTiet) AS s
               ON t.MaKho = @MaKho AND t.MaVT = s.MaVT
            WHEN MATCHED THEN
                UPDATE SET t.SoLuong = t.SoLuong + s.SoLuong,
                           t.NgayCapNhat = SYSDATETIME()
            WHEN NOT MATCHED THEN
                INSERT (MaKho, MaVT, SoLuong, NgayCapNhat)
                VALUES (@MaKho, s.MaVT, s.SoLuong, SYSDATETIME());

        COMMIT TRANSACTION;
        PRINT N'[' + @MaKho + N'] Đã nhập kho, mã phiếu: ' + @MaPN;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

/* ----------------------------------------------------------------------------
   5. F2 - XUẤT VẬT TƯ KHỎI KHO

   Điểm mấu chốt: dòng SELECT ... WITH (UPDLOCK, HOLDLOCK) đặt KHÓA CẬP NHẬT
   ngay lúc ĐỌC để kiểm tra tồn. Nếu chỉ SELECT thường rồi mới UPDATE thì hai
   phiên chạy đồng thời sẽ cùng đọc được số tồn cũ và cùng cho phép xuất -
   lỗi LOST UPDATE. Tình huống này được demo đầy đủ trong file 07.
   ---------------------------------------------------------------------------- */
IF OBJECT_ID('dbo.sp_XuatKho', 'P') IS NOT NULL DROP PROCEDURE dbo.sp_XuatKho;
GO
CREATE PROCEDURE dbo.sp_XuatKho
    @NguoiNhan NVARCHAR(100),
    @NguoiLap  NVARCHAR(50),
    @ChiTiet   dbo.ChiTietVatTu_Type READONLY,
    @MaPX      CHAR(7) = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @MaKho CHAR(5) = dbo.fn_MaKhoHienTai();

    IF NOT EXISTS (SELECT 1 FROM @ChiTiet)
    BEGIN
        RAISERROR (N'Phiếu xuất phải có ít nhất một dòng chi tiết.', 16, 1);
        RETURN;
    END

    BEGIN TRY
        BEGIN TRANSACTION;

            /* KIỂM TRA TỒN có đặt khóa - chống lost update.
               Bảng tạm giữ kết quả để báo lỗi cho rõ ràng.                     */
            DECLARE @Thieu TABLE (MaVT CHAR(5), TonHienCo INT, SoLuongXuat INT);

            INSERT INTO @Thieu (MaVT, TonHienCo, SoLuongXuat)
            SELECT c.MaVT, ISNULL(t.SoLuong, 0), c.SoLuong
            FROM   @ChiTiet c
            LEFT JOIN TonKho t WITH (UPDLOCK, HOLDLOCK)
                   ON t.MaKho = @MaKho AND t.MaVT = c.MaVT
            WHERE  ISNULL(t.SoLuong, 0) < c.SoLuong;

            IF EXISTS (SELECT 1 FROM @Thieu)
            BEGIN
                DECLARE @msg NVARCHAR(600) = N'KHÔNG ĐỦ TỒN KHO tại ' + @MaKho + N': ';
                SELECT @msg = @msg + MaVT + N' (còn ' + CAST(TonHienCo AS NVARCHAR(10))
                                   + N', cần ' + CAST(SoLuongXuat AS NVARCHAR(10)) + N')  '
                FROM @Thieu;
                RAISERROR (@msg, 16, 1);
            END

            SET @MaPX = dbo.fn_MaPhieuKeTiep('PX');

            INSERT INTO PhieuXuat (MaPX, MaKho, NgayXuat, NguoiNhan, NguoiLap, TrangThai)
            VALUES (@MaPX, @MaKho, SYSDATETIME(), @NguoiNhan, @NguoiLap, 'HOAN_TAT');

            INSERT INTO ChiTietXuat (MaPX, MaVT, SoLuong, DonGia)
            SELECT @MaPX, MaVT, SoLuong, DonGia FROM @ChiTiet;

            UPDATE t
               SET t.SoLuong     = t.SoLuong - c.SoLuong,
                   t.NgayCapNhat = SYSDATETIME()
            FROM TonKho t
            JOIN @ChiTiet c ON c.MaVT = t.MaVT
            WHERE t.MaKho = @MaKho;

        COMMIT TRANSACTION;
        PRINT N'[' + @MaKho + N'] Đã xuất kho, mã phiếu: ' + @MaPX;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

/* ----------------------------------------------------------------------------
   6. F3 - TRA CỨU TỒN KHO TẠI CHỖ (truy vấn CỤC BỘ, không qua mạng)
   ---------------------------------------------------------------------------- */
IF OBJECT_ID('dbo.sp_TraCuuTonKho', 'P') IS NOT NULL DROP PROCEDURE dbo.sp_TraCuuTonKho;
GO
CREATE PROCEDURE dbo.sp_TraCuuTonKho
    @MaVT CHAR(5) = NULL          -- NULL = xem toàn bộ mảnh của site này
AS
BEGIN
    SET NOCOUNT ON;
    SELECT k.TenKho, t.MaVT, v.TenVT, v.DonViTinh,
           t.SoLuong, v.MucTonToiThieu,
           CAST(t.SoLuong * v.DonGia AS DECIMAL(18,0)) AS GiaTriTon,
           t.NgayCapNhat
    FROM   TonKho t
    JOIN   VatTu  v ON v.MaVT  = t.MaVT
    JOIN   Kho    k ON k.MaKho = t.MaKho
    WHERE  (@MaVT IS NULL OR t.MaVT = @MaVT)
    ORDER BY t.MaVT;
END
GO

/* ----------------------------------------------------------------------------
   7. F7 - CẢNH BÁO VẬT TƯ DƯỚI MỨC TỒN TỐI THIỂU

   Đây là nguồn phát sinh nghiệp vụ ĐIỀU CHUYỂN: kho nào thiếu thì xin kho
   khác chuyển sang (xem file 06).
   ---------------------------------------------------------------------------- */
IF OBJECT_ID('dbo.sp_CanhBaoTonToiThieu', 'P') IS NOT NULL DROP PROCEDURE dbo.sp_CanhBaoTonToiThieu;
GO
CREATE PROCEDURE dbo.sp_CanhBaoTonToiThieu
AS
BEGIN
    SET NOCOUNT ON;
    SELECT dbo.fn_MaKhoHienTai() AS MaKho,
           t.MaVT, v.TenVT, t.SoLuong AS TonHienCo,
           v.MucTonToiThieu, v.MucTonToiThieu - t.SoLuong AS ThieuHut,
           N'CẦN BỔ SUNG' AS CanhBao
    FROM   TonKho t
    JOIN   VatTu  v ON v.MaVT = t.MaVT
    WHERE  t.SoLuong < v.MucTonToiThieu
    ORDER BY (v.MucTonToiThieu - t.SoLuong) DESC;
END
GO

/* ============================================================================
   8. CHẠY THỬ  -  bỏ chú thích để kiểm tra sau khi cài đặt
   ============================================================================ */

PRINT N'===================================================================';
PRINT N' SITE HIỆN TẠI : ' + dbo.fn_MaKhoHienTai() + N'   (database ' + DB_NAME() + N')';
PRINT N' Mã phiếu nhập kế tiếp : ' + dbo.fn_MaPhieuKeTiep('PN');
PRINT N' Mã phiếu xuất kế tiếp : ' + dbo.fn_MaPhieuKeTiep('PX');
PRINT N'===================================================================';
GO

-- ---- Thử F1: nhập 100 bao xi măng + 50 cây thép -----------------------------
DECLARE @ct dbo.ChiTietVatTu_Type;
INSERT INTO @ct (MaVT, SoLuong, DonGia) VALUES
    ('VT001', 100,  95000),
    ('VT002',  50, 185000);

DECLARE @pn CHAR(7);
EXEC dbo.sp_NhapKho @MaNCC = 'NCC01', @NguoiLap = N'Kiểm thử hệ thống',
                    @ChiTiet = @ct, @MaPN = @pn OUTPUT;

SELECT MaPN, MaVT, SoLuong, DonGia FROM ChiTietNhap WHERE MaPN = @pn;
GO

-- ---- Thử F2: xuất 30 bao xi măng -------------------------------------------
DECLARE @ct2 dbo.ChiTietVatTu_Type;
INSERT INTO @ct2 (MaVT, SoLuong, DonGia) VALUES ('VT001', 30, 98000);

DECLARE @px CHAR(7);
EXEC dbo.sp_XuatKho @NguoiNhan = N'Công trình kiểm thử', @NguoiLap = N'Kiểm thử hệ thống',
                    @ChiTiet = @ct2, @MaPX = @px OUTPUT;
GO

-- ---- Thử F2 thất bại: xuất nhiều hơn tồn -> PHẢI báo lỗi và rollback --------
BEGIN TRY
    DECLARE @ct3 dbo.ChiTietVatTu_Type;
    INSERT INTO @ct3 (MaVT, SoLuong, DonGia) VALUES ('VT001', 999999, 98000);

    DECLARE @px3 CHAR(7);
    EXEC dbo.sp_XuatKho @NguoiNhan = N'Đơn hàng quá lớn', @NguoiLap = N'Kiểm thử hệ thống',
                        @ChiTiet = @ct3, @MaPX = @px3 OUTPUT;
    PRINT N'SAI: đáng lẽ phải bị chặn!';
END TRY
BEGIN CATCH
    PRINT N'ĐÚNG: đã chặn - ' + ERROR_MESSAGE();
END CATCH
GO

-- ---- Thử F3 và F7 ----------------------------------------------------------
EXEC dbo.sp_TraCuuTonKho;
EXEC dbo.sp_CanhBaoTonToiThieu;
GO

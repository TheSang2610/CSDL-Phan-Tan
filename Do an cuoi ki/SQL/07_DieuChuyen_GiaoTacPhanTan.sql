/* ============================================================================
   ĐỒ ÁN CUỐI KỲ - CSDL PHÂN TÁN - QUẢN LÝ KHO VẬT TƯ ĐA CHI NHÁNH
   ----------------------------------------------------------------------------
   FILE 07 : ĐIỀU CHUYỂN VẬT TƯ GIỮA HAI KHO
             GIAO TÁC PHÂN TÁN 2 PHA (2PC) QUA MS DTC        (mục 3.7 báo cáo)

   CHẠY TẠI : MIGNON\KHO_A   (database KhoA)

   ĐÁP ỨNG YÊU CẦU ĐỀ BÀI:
       "Kho A chuyển 50 sản phẩm → Kho B.
        Nếu giao dịch thất bại giữa chừng thì dữ liệu phải được xử lý nhất quán."

   ----------------------------------------------------------------------------
   ĐIỀU KIỆN CHẠY ĐƯỢC
     1. Dịch vụ MS DTC đang chạy
            Set-Service MSDTC -StartupType Automatic ; Start-Service MSDTC
     2. Đã bật Network DTC Access  (dcomcnfg -> Local DTC -> Security)
     3. Linked Server đã bật 'remote proc transaction promotion' (file 05 đã làm)

   ----------------------------------------------------------------------------
   CƠ CHẾ 2 PHA (Two-Phase Commit) DO MS DTC ĐIỀU PHỐI

     PHA 1 - PREPARE : DTC hỏi CẢ HAI site "sẵn sàng commit chưa?"
                       Mỗi site ghi nhật ký và trả lời YES / NO.
     PHA 2 - COMMIT  : Nếu MỌI site trả lời YES  -> ra lệnh commit đồng loạt.
                       Chỉ cần MỘT site nói NO hoặc mất kết nối
                                            -> ROLLBACK TOÀN BỘ ở cả hai nơi.

     => Không bao giờ xảy ra tình trạng Kho A đã trừ hàng mà Kho B chưa cộng.
   ============================================================================ */

SET NOCOUNT ON;
USE KhoA;
GO

/* ############################################################################
   PHẦN 1 - THỦ TỤC ĐIỀU CHUYỂN

   ⚠️ TRIỂN KHAI Ở CẢ BA SITE

   Thủ tục này KHÔNG viết cứng tên kho nào cả: kho nguồn lấy từ
   dbo.fn_MaKhoHienTai(), tên máy của kho đích lấy từ cột Kho.ServerName.
   Nhờ vậy cùng một đoạn mã chạy được ở KHO_A, KHO_B lẫn KHO_C, và kho nào
   cũng CHỦ ĐỘNG gửi hàng đi được chứ không chỉ Kho Trung tâm.

   Cách triển khai: bôi đen PHẦN 1 này rồi bấm F5 lần lượt ở cả ba cửa sổ
   (nhớ đổi USE KhoA thành KhoB / KhoC cho đúng site).

   Các PHẦN 3, 4, 5 bên dưới (kịch bản T1, T2, T3) thì CHỈ chạy ở KHO_A.
   ############################################################################ */
IF OBJECT_ID('dbo.sp_DieuChuyenVatTu', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_DieuChuyenVatTu;
GO

CREATE PROCEDURE dbo.sp_DieuChuyenVatTu
    @MaKhoDich CHAR(5),
    @MaVT      CHAR(5),
    @SoLuong   INT,
    @NguoiLap  NVARCHAR(50)   = N'Hệ thống',
    @GhiChu    NVARCHAR(200)  = NULL,
    @GayLoiThuNghiem BIT      = 0,      -- =1: cố tình gây lỗi SAU khi đã trừ kho nguồn
    @MaDC      CHAR(6)        = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;          -- bắt buộc với giao tác phân tán

    DECLARE @MaKhoNguon CHAR(5) = dbo.fn_MaKhoHienTai();
    DECLARE @TonNguon   INT;
    DECLARE @ServerDich SYSNAME, @DbDich SYSNAME, @sql NVARCHAR(MAX);

    /* ---- Kiểm tra đầu vào (làm TRƯỚC khi mở giao tác cho nhẹ) ---- */
    IF @MaKhoDich = @MaKhoNguon
    BEGIN
        RAISERROR (N'Kho nguồn và kho đích không được trùng nhau.', 16, 1);
        RETURN;
    END

    IF @SoLuong <= 0
    BEGIN
        RAISERROR (N'Số lượng điều chuyển phải lớn hơn 0.', 16, 1);
        RETURN;
    END

    SELECT @ServerDich = ServerName FROM Kho WHERE MaKho = @MaKhoDich;
    IF @ServerDich IS NULL
    BEGIN
        RAISERROR (N'Không tìm thấy kho đích trong danh mục.', 16, 1);
        RETURN;
    END

    SET @DbDich = N'Kho' + RIGHT(@MaKhoDich, 1);   -- KHO_B -> KhoB

    BEGIN TRY
        /* ================= MỞ GIAO TÁC PHÂN TÁN ================= */
        BEGIN DISTRIBUTED TRANSACTION;

        /* --- B1. Khoá và kiểm tra tồn tại KHO NGUỒN ---------------
           UPDLOCK giữ khoá tới hết giao tác, chống hai phiên cùng
           điều chuyển một vật tư và cùng thấy đủ hàng (lost update). */
        SELECT @TonNguon = SoLuong
        FROM   TonKho WITH (UPDLOCK, HOLDLOCK)
        WHERE  MaKho = @MaKhoNguon AND MaVT = @MaVT;

        IF @TonNguon IS NULL
        BEGIN
            RAISERROR (N'Kho nguồn %s không có vật tư %s.', 16, 1, @MaKhoNguon, @MaVT);
        END

        IF @TonNguon < @SoLuong
        BEGIN
            RAISERROR (N'KHÔNG ĐỦ HÀNG: kho %s chỉ còn %d, cần chuyển %d.',
                       16, 1, @MaKhoNguon, @TonNguon, @SoLuong);
        END

        /* --- B2. Sinh mã phiếu, nhúng ký tự kho nguồn để không trùng giữa site --- */
        SELECT @MaDC = N'DC' + RIGHT(@MaKhoNguon, 1)
                     + RIGHT(N'000' + CAST(ISNULL(MAX(CAST(RIGHT(MaDC,3) AS INT)),0) + 1
                                           AS NVARCHAR(3)), 3)
        FROM   PhieuDieuChuyen
        WHERE  MaDC LIKE N'DC' + RIGHT(@MaKhoNguon, 1) + N'%';

        /* --- B3. TRỪ kho nguồn (site cục bộ) ---------------------- */
        UPDATE TonKho
        SET    SoLuong     = SoLuong - @SoLuong,
               NgayCapNhat = SYSDATETIME()
        WHERE  MaKho = @MaKhoNguon AND MaVT = @MaVT;

        /* --- B4. Ghi phiếu điều chuyển tại kho nguồn -------------- */
        INSERT INTO PhieuDieuChuyen
               (MaDC, MaKhoNguon, MaKhoDich, MaVT, SoLuong, NgayLap, TrangThai, GhiChu)
        VALUES (@MaDC, @MaKhoNguon, @MaKhoDich, @MaVT, @SoLuong,
                SYSDATETIME(), 'CHO_DUYET', @GhiChu);

        /* ===== ĐIỂM GÂY LỖI THỬ NGHIỆM =====
           Tới đây kho nguồn ĐÃ BỊ TRỪ. Nếu bung lỗi ngay lúc này mà dữ liệu
           vẫn nhất quán thì chứng minh được 2PC làm đúng việc của nó.       */
        IF @GayLoiThuNghiem = 1
            RAISERROR (N'>>> LỖI MÔ PHỎNG: mất kết nối tới kho đích giữa chừng <<<', 16, 1);

        /* --- B5. CỘNG kho đích (site TỪ XA qua Linked Server) ----- */
        SET @sql = N'
            IF EXISTS (SELECT 1 FROM ' + QUOTENAME(@ServerDich) + N'.' + QUOTENAME(@DbDich)
                     + N'.dbo.TonKho WHERE MaKho = @kho AND MaVT = @vt)
                UPDATE ' + QUOTENAME(@ServerDich) + N'.' + QUOTENAME(@DbDich) + N'.dbo.TonKho
                SET    SoLuong = SoLuong + @sl, NgayCapNhat = SYSDATETIME()
                WHERE  MaKho = @kho AND MaVT = @vt;
            ELSE
                INSERT INTO ' + QUOTENAME(@ServerDich) + N'.' + QUOTENAME(@DbDich)
                     + N'.dbo.TonKho (MaKho, MaVT, SoLuong, NgayCapNhat)
                VALUES (@kho, @vt, @sl, SYSDATETIME());';

        EXEC sp_executesql @sql,
             N'@kho CHAR(5), @vt CHAR(5), @sl INT',
             @kho = @MaKhoDich, @vt = @MaVT, @sl = @SoLuong;

        /* --- B6. Ghi phiếu điều chuyển tại kho đích --------------- */
        SET @sql = N'
            INSERT INTO ' + QUOTENAME(@ServerDich) + N'.' + QUOTENAME(@DbDich)
                 + N'.dbo.PhieuDieuChuyen
                   (MaDC, MaKhoNguon, MaKhoDich, MaVT, SoLuong, NgayLap, TrangThai, GhiChu)
            VALUES (@dc, @nguon, @dich, @vt, @sl, SYSDATETIME(), ''HOAN_TAT'', @gc);';

        EXEC sp_executesql @sql,
             N'@dc CHAR(6), @nguon CHAR(5), @dich CHAR(5), @vt CHAR(5), @sl INT, @gc NVARCHAR(200)',
             @dc = @MaDC, @nguon = @MaKhoNguon, @dich = @MaKhoDich,
             @vt = @MaVT, @sl = @SoLuong, @gc = @GhiChu;

        /* --- B7. Chốt trạng thái phiếu tại kho nguồn -------------- */
        UPDATE PhieuDieuChuyen SET TrangThai = 'HOAN_TAT' WHERE MaDC = @MaDC;

        /* ===== MS DTC CHẠY 2PC TẠI ĐÂY ===== */
        COMMIT TRANSACTION;

        PRINT N'✔ THÀNH CÔNG  ' + @MaDC + N' : ' + @MaKhoNguon + N' -> ' + @MaKhoDich
            + N'  |  ' + @MaVT + N' x ' + CAST(@SoLuong AS NVARCHAR(10));
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        SET @MaDC = NULL;
        PRINT N'✘ THẤT BẠI - ĐÃ ROLLBACK TOÀN BỘ : ' + ERROR_MESSAGE();
        THROW;
    END CATCH
END
GO

/* ############################################################################
   PHẦN 2 - HÀM XEM TỒN KHO HAI SITE (dùng để chụp trước/sau)
   ############################################################################ */
IF OBJECT_ID('dbo.v_TonKho_AB', 'V') IS NOT NULL DROP VIEW dbo.v_TonKho_AB;
GO
CREATE VIEW dbo.v_TonKho_AB AS
    SELECT N'KHO_A (Trung tâm)' AS Site, MaVT, SoLuong, NgayCapNhat
    FROM   KhoA.dbo.TonKho
    UNION ALL
    SELECT N'KHO_B (Miền Bắc)', MaVT, SoLuong, NgayCapNhat
    FROM   [Mignon\KHO_B].KhoB.dbo.TonKho;
GO

/* ############################################################################
   PHẦN 3 - KỊCH BẢN T1 : ĐIỀU CHUYỂN 50 SẢN PHẨM  KHO_A -> KHO_B
            (đúng yêu cầu của đề bài)

   BỐI CẢNH NGHIỆP VỤ
     Kho B báo thiếu VT009 (Bóng đèn LED 9W): tồn 150, mức tối thiểu 200.
     Thiếu đúng 50 -> Kho Trung tâm điều chuyển sang 50 đơn vị.
   ############################################################################ */
PRINT N'';
PRINT N'╔══════════════════════════════════════════════════════════════════╗';
PRINT N'║  T1 - ĐIỀU CHUYỂN 50 SẢN PHẨM VT009 :  KHO_A  ->  KHO_B          ║';
PRINT N'╚══════════════════════════════════════════════════════════════════╝';
GO

PRINT N'--- TRƯỚC KHI ĐIỀU CHUYỂN ---';
SELECT * FROM dbo.v_TonKho_AB WHERE MaVT = 'VT009';
GO

DECLARE @dc CHAR(6);
EXEC dbo.sp_DieuChuyenVatTu
     @MaKhoDich = 'KHO_B', @MaVT = 'VT009', @SoLuong = 50,
     @NguoiLap  = N'Phòng Điều phối',
     @GhiChu    = N'Bổ sung cho Kho Miền Bắc do dưới mức tồn tối thiểu',
     @MaDC      = @dc OUTPUT;
GO

PRINT N'--- SAU KHI ĐIỀU CHUYỂN (A giảm 50, B tăng 50) ---';
SELECT * FROM dbo.v_TonKho_AB WHERE MaVT = 'VT009';
GO

PRINT N'--- PHIẾU ĐIỀU CHUYỂN GHI Ở CẢ HAI SITE ---';
SELECT N'KHO_A' AS LuuTai, MaDC, MaKhoNguon, MaKhoDich, MaVT, SoLuong, TrangThai
FROM   KhoA.dbo.PhieuDieuChuyen
UNION ALL
SELECT N'KHO_B', MaDC, MaKhoNguon, MaKhoDich, MaVT, SoLuong, TrangThai
FROM   [Mignon\KHO_B].KhoB.dbo.PhieuDieuChuyen
ORDER BY MaDC, LuuTai;
GO

/* ############################################################################
   PHẦN 4 - KỊCH BẢN T2 : KHO NGUỒN KHÔNG ĐỦ HÀNG
            Giao tác bị từ chối NGAY, không site nào bị đụng tới.
   ############################################################################ */
PRINT N'';
PRINT N'╔══════════════════════════════════════════════════════════════════╗';
PRINT N'║  T2 - CHUYỂN 999999 ĐƠN VỊ (vượt xa tồn kho)                     ║';
PRINT N'╚══════════════════════════════════════════════════════════════════╝';
GO

PRINT N'--- TRƯỚC ---';
SELECT * FROM dbo.v_TonKho_AB WHERE MaVT = 'VT001';
GO

BEGIN TRY
    DECLARE @dc2 CHAR(6);
    EXEC dbo.sp_DieuChuyenVatTu
         @MaKhoDich = 'KHO_B', @MaVT = 'VT001', @SoLuong = 999999,
         @MaDC = @dc2 OUTPUT;
END TRY
BEGIN CATCH
    PRINT N'   >>> Đã bắt được lỗi đúng như mong đợi';
END CATCH
GO

PRINT N'--- SAU (phải GIỐNG HỆT bảng TRƯỚC) ---';
SELECT * FROM dbo.v_TonKho_AB WHERE MaVT = 'VT001';
GO

/* ############################################################################
   PHẦN 5 - KỊCH BẢN T3 : LỖI XẢY RA GIỮA CHỪNG  ⭐ QUAN TRỌNG NHẤT

   Đây chính là tình huống đề bài yêu cầu chứng minh:
       "Nếu giao dịch thất bại giữa chừng thì dữ liệu phải được xử lý nhất quán"

   Tham số @GayLoiThuNghiem = 1 khiến thủ tục bung lỗi NGAY SAU KHI đã trừ kho
   nguồn và đã ghi phiếu, NHƯNG TRƯỚC KHI cộng cho kho đích - tức là đúng thời
   điểm nguy hiểm nhất. Nếu không có 2PC thì hàng sẽ "bốc hơi": Kho A mất 50
   mà Kho B không nhận được gì.
   ############################################################################ */
PRINT N'';
PRINT N'╔══════════════════════════════════════════════════════════════════╗';
PRINT N'║  T3 - LỖI GIỮA CHỪNG: ĐÃ TRỪ KHO NGUỒN RỒI MỚI BUNG LỖI          ║';
PRINT N'╚══════════════════════════════════════════════════════════════════╝';
GO

PRINT N'--- TRƯỚC ---';
SELECT * FROM dbo.v_TonKho_AB WHERE MaVT = 'VT001';
SELECT COUNT(*) AS SoPhieu_KhoA FROM KhoA.dbo.PhieuDieuChuyen;
GO

BEGIN TRY
    DECLARE @dc3 CHAR(6);
    EXEC dbo.sp_DieuChuyenVatTu
         @MaKhoDich = 'KHO_B', @MaVT = 'VT001', @SoLuong = 50,
         @GhiChu = N'Giao tác cố tình cho thất bại giữa chừng',
         @GayLoiThuNghiem = 1,
         @MaDC = @dc3 OUTPUT;
END TRY
BEGIN CATCH
    PRINT N'   >>> Giao tác đã bị huỷ, MS DTC rollback cả hai site';
END CATCH
GO

PRINT N'--- SAU (tồn kho PHẢI y nguyên, số phiếu PHẢI không đổi) ---';
SELECT * FROM dbo.v_TonKho_AB WHERE MaVT = 'VT001';
SELECT COUNT(*) AS SoPhieu_KhoA FROM KhoA.dbo.PhieuDieuChuyen;
GO

/* ############################################################################
   PHẦN 6 - TỔNG KẾT
   ############################################################################ */
PRINT N'';
PRINT N'╔══════════════════════════════════════════════════════════════════╗';
PRINT N'║  TỔNG KẾT                                                        ║';
PRINT N'╚══════════════════════════════════════════════════════════════════╝';
GO

SELECT N'Tổng tồn VT009 toàn hệ thống' AS KiemTra,
       (SELECT SUM(SoLuong) FROM KhoA.dbo.TonKho WHERE MaVT='VT009')
     + (SELECT SUM(SoLuong) FROM [Mignon\KHO_B].KhoB.dbo.TonKho WHERE MaVT='VT009')
     + ISNULL((SELECT SUM(SoLuong) FROM [Mignon\KHO_C].KhoC.dbo.TonKho WHERE MaVT='VT009'),0)
       AS TongSoLuong,
       N'Điều chuyển chỉ DI CHUYỂN hàng giữa các kho, KHÔNG làm thay đổi tổng' AS YNghia;
GO

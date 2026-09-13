/* ============================================================================
   ĐỒ ÁN CUỐI KỲ - CSDL PHÂN TÁN - QUẢN LÝ KHO VẬT TƯ ĐA CHI NHÁNH
   ----------------------------------------------------------------------------
   FILE 12 : THỦ TỤC PHỤC VỤ PHẦN MỀM ỨNG DỤNG CHO CÁC TRẠM

        · Mục báo cáo : "Viết phần mềm ứng dụng cho các trạm" (phần Bonus)

   ----------------------------------------------------------------------------
   ⚠️  CHẠY TRÊN CẢ BA SITE - KHÔNG SỬA GÌ

       Mignon\KHO_A   ->  USE KhoA  ->  F5
       Mignon\KHO_B   ->  USE KhoB  ->  F5
       Mignon\KHO_C   ->  USE KhoC  ->  F5

   ----------------------------------------------------------------------------
   VÌ SAO CẦN THÊM FILE NÀY

   Thủ tục sp_TonKhoToanHeThong ở file 09 đọc danh sách kho bằng câu
   KhoA.dbo.Kho - tên cơ sở dữ liệu ghi cứng. Chạy tại KHO_A thì đúng, nhưng
   đem sang máy của KHO_B thì trên máy đó KHÔNG có cơ sở dữ liệu tên KhoA,
   câu lệnh sẽ hỏng ngay.

   Phần mềm ứng dụng thì mỗi trạm chạy một bản trên máy của mình, nên cần một
   thủ tục chạy được ở BẤT KỲ site nào. Thủ tục dưới đây đọc bảng Kho CỤC BỘ -
   bảng này được nhân bản về cả ba site nên site nào cũng có bản giống hệt.

   Đây chính là lợi ích thực tế của việc nhân bản danh mục, đáng nêu trong báo
   cáo: nhờ có bản sao tại chỗ mà ứng dụng ở trạm biết được địa chỉ của hai
   site kia mà không phải hỏi vòng qua mạng.
   ============================================================================ */

SET NOCOUNT ON;
GO

DECLARE @db SYSNAME = DB_NAME();
IF @db NOT IN ('KhoA','KhoB','KhoC')
    RAISERROR (N'>>> ĐANG Ở SAI DATABASE (%s). Chọn KhoA / KhoB / KhoC ở ô dropdown SSMS rồi chạy lại. <<<',
               16, 1, @db);
ELSE
    PRINT N'Database hiện tại: ' + @db + N'  -> chạy tiếp được';
GO


/* ############################################################################
   1. TỒN KHO TOÀN HỆ THỐNG - chạy được ở bất kỳ site nào
   ############################################################################ */
IF OBJECT_ID('dbo.sp_TonKhoToanHeThong_Site', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_TonKhoToanHeThong_Site;
GO

CREATE PROCEDURE dbo.sp_TonKhoToanHeThong_Site
    @MaVT CHAR(5) = NULL          -- NULL = xem tất cả vật tư
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @SQL     NVARCHAR(MAX) = N'';
    DECLARE @MaKhoNay CHAR(5) = dbo.fn_MaKhoHienTai();
    DECLARE @MaKho CHAR(5), @TenKho NVARCHAR(50), @Server NVARCHAR(128), @DB SYSNAME;

    /* Đọc bảng Kho CỤC BỘ. Bảng này là bản sao do replication đẩy về, site nào
       cũng có, nên thủ tục không phụ thuộc vào việc KhoA có mặt trên máy này. */
    DECLARE cur CURSOR LOCAL FAST_FORWARD FOR
        SELECT MaKho, TenKho, ServerName FROM dbo.Kho ORDER BY MaKho;
    OPEN cur;
    FETCH NEXT FROM cur INTO @MaKho, @TenKho, @Server;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @DB = N'Kho' + UPPER(RIGHT(RTRIM(@MaKho), 1));
        IF @SQL <> N'' SET @SQL += N' UNION ALL ';

        /* Tiền tố N bắt buộc: thiếu nó thì 'Kho Miền Bắc' bị hiểu là VARCHAR,
           dấu tiếng Việt rơi mất và in ra thành 'Kho Mi?n B?c'.               */
        IF @MaKho = @MaKhoNay          -- site tại chỗ: đọc thẳng, không qua mạng
            SET @SQL += N'SELECT N' + QUOTENAME(@TenKho, '''') + N' AS TenKho,
                                 MaKho, MaVT, SoLuong, NgayCapNhat
                          FROM dbo.TonKho';
        ELSE                           -- site từ xa: đi qua Linked Server
            SET @SQL += N'SELECT N' + QUOTENAME(@TenKho, '''') + N' AS TenKho,
                                 MaKho, MaVT, SoLuong, NgayCapNhat
                          FROM ' + QUOTENAME(@Server) + N'.' + QUOTENAME(@DB)
                       + N'.dbo.TonKho';

        IF @MaVT IS NOT NULL
            SET @SQL += N' WHERE MaVT = ' + QUOTENAME(@MaVT, '''');

        FETCH NEXT FROM cur INTO @MaKho, @TenKho, @Server;
    END
    CLOSE cur; DEALLOCATE cur;

    /* Ghép thêm tên vật tư từ danh mục CỤC BỘ - cũng là bảng nhân bản, nên
       phép nối chạy tại chỗ, không tốn thêm vòng nào qua mạng.               */
    SET @SQL = N'
        SELECT  t.TenKho, t.MaKho, t.MaVT, v.TenVT, v.DonViTinh,
                t.SoLuong, v.DonGia,
                CAST(t.SoLuong * v.DonGia AS DECIMAL(18,0)) AS GiaTriTon,
                v.MucTonToiThieu,
                CASE WHEN t.SoLuong < v.MucTonToiThieu THEN 1 ELSE 0 END AS ThieuHang,
                t.NgayCapNhat
        FROM  ( ' + @SQL + N' ) AS t
        JOIN  dbo.VatTu v ON v.MaVT = t.MaVT
        ORDER BY t.MaVT, t.MaKho;';

    EXEC sp_executesql @SQL;
END
GO

PRINT N'   Đã tạo sp_TonKhoToanHeThong_Site';
GO


/* ############################################################################
   2. THÔNG TIN SITE - phần mềm hiện lên đầu trang để người dùng biết
      mình đang đứng ở trạm nào, nối bằng đường nào
   ############################################################################ */
IF OBJECT_ID('dbo.sp_ThongTinSite', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_ThongTinSite;
GO

CREATE PROCEDURE dbo.sp_ThongTinSite
AS
BEGIN
    SET NOCOUNT ON;
    SELECT  k.MaKho,
            k.TenKho,
            k.DiaChi,
            DB_NAME()                                           AS CSDL,
            @@SERVERNAME                                        AS MayChu,
            CAST(SERVERPROPERTY('MachineName') AS NVARCHAR(60))  AS MayTinh,
            c.net_transport                                     AS GiaoThuc,
            c.local_net_address                                 AS DiaChiMayChu,
            c.local_tcp_port                                    AS Cong,
            (SELECT COUNT(*) FROM dbo.TonKho)                   AS SoDongTonKho,
            (SELECT COUNT(*) FROM dbo.VatTu)                    AS SoVatTu
    FROM    dbo.Kho k
    CROSS JOIN sys.dm_exec_connections c
    WHERE   k.MaKho = dbo.fn_MaKhoHienTai()
      AND   c.session_id = @@SPID;
END
GO

PRINT N'   Đã tạo sp_ThongTinSite';
GO


/* ############################################################################
   3. DANH SÁCH KHO ĐÍCH - dùng cho ô chọn kho khi điều chuyển
   ############################################################################ */
IF OBJECT_ID('dbo.sp_KhoKhac', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_KhoKhac;
GO

CREATE PROCEDURE dbo.sp_KhoKhac
AS
BEGIN
    SET NOCOUNT ON;
    SELECT MaKho, TenKho, DiaChi
    FROM   dbo.Kho
    WHERE  MaKho <> dbo.fn_MaKhoHienTai()
    ORDER  BY MaKho;
END
GO

PRINT N'   Đã tạo sp_KhoKhac';
GO


/* ############################################################################
   4. LỊCH SỬ CHỨNG TỪ CỦA SITE NÀY - để ứng dụng hiện bảng theo dõi
   ############################################################################ */
IF OBJECT_ID('dbo.sp_LichSuChungTu', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_LichSuChungTu;
GO

CREATE PROCEDURE dbo.sp_LichSuChungTu
    @SoDong INT = 20
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP (@SoDong) * FROM (
        SELECT N'Nhập kho'      AS Loai, pn.MaPN AS MaChungTu, pn.NgayNhap AS ThoiDiem,
               pn.NguoiLap, pn.TrangThai,
               CAST((SELECT SUM(SoLuong) FROM dbo.ChiTietNhap c WHERE c.MaPN = pn.MaPN) AS NVARCHAR(20)) AS SoLuong,
               N'' AS GhiChu
        FROM   dbo.PhieuNhap pn
        UNION ALL
        SELECT N'Xuất kho', px.MaPX, px.NgayXuat, px.NguoiLap, px.TrangThai,
               CAST((SELECT SUM(SoLuong) FROM dbo.ChiTietXuat c WHERE c.MaPX = px.MaPX) AS NVARCHAR(20)),
               px.NguoiNhan
        FROM   dbo.PhieuXuat px
        UNION ALL
        SELECT CASE WHEN dc.MaKhoNguon = dbo.fn_MaKhoHienTai()
                    THEN N'Chuyển đi' ELSE N'Nhận về' END,
               dc.MaDC, dc.NgayLap, N'', dc.TrangThai,
               CAST(dc.SoLuong AS NVARCHAR(20)),
               dc.MaKhoNguon + N' -> ' + dc.MaKhoDich
        FROM   dbo.PhieuDieuChuyen dc
    ) AS t
    ORDER BY ThoiDiem DESC;
END
GO

PRINT N'   Đã tạo sp_LichSuChungTu';
PRINT N'';
PRINT N'>>> Xong. Giờ chạy phần mềm trong thư mục UngDungWeb. <<<';
GO

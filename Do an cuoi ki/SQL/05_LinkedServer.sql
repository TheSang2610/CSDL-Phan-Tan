/* ============================================================================
   ĐỒ ÁN CUỐI KỲ - CSDL PHÂN TÁN - QUẢN LÝ KHO VẬT TƯ ĐA CHI NHÁNH
   ----------------------------------------------------------------------------
   FILE 05 : TẠO LINK CSDL GIỮA CÁC SERVER   (mục 3.5 của báo cáo)

   CHẠY TẠI : CẢ BA instance - KHO_A , KHO_B , KHO_C
              Script tự nhận biết mình là site nào và chỉ tạo 2 link còn thiếu.

   MỤC ĐÍCH
     Dựng 6 đường liên kết hai chiều giữa 3 site để phục vụ:
       - Truy vấn phân tán  (file 09) : đọc tồn kho của site khác
       - Giao tác phân tán  (file 07) : điều chuyển vật tư giữa 2 kho

                        KHO_A
                       /     \
                      /       \
                 KHO_B ------- KHO_C

     Mỗi cạnh là 2 link (đi và về) => tổng 6 link trên toàn hệ thống.
   ============================================================================ */

SET NOCOUNT ON;
GO

USE master;
GO

/* ----------------------------------------------------------------------------
   1. KHAI BÁO THAM SỐ
   ---------------------------------------------------------------------------- */
DECLARE @MayChu    SYSNAME      = CAST(SERVERPROPERTY('MachineName') AS SYSNAME);
DECLARE @SiteToi   SYSNAME      = @@SERVERNAME;
DECLARE @TaiKhoan  SYSNAME      = N'sa';
DECLARE @MatKhau   NVARCHAR(50) = N'123';   -- mật khẩu 'sa' đặt lúc cài đặt
                                            -- ĐỔI Ở ĐÂY nếu bạn dùng mật khẩu khác

PRINT N'Máy chủ vật lý : ' + @MayChu;
PRINT N'Site hiện tại  : ' + @SiteToi;
PRINT N'';

/* ----------------------------------------------------------------------------
   2. TẠO LINKED SERVER TỚI HAI SITE CÒN LẠI

   @server   : tên linked server, đặt trùng tên instance cho dễ đọc câu truy vấn
   @srvproduct = '' + @provider = 'SQLNCLI'/'MSOLEDBSQL' : chuẩn cho SQL Server
   @datasrc  : chuỗi kết nối thực tế  MAYCHU\TEN_INSTANCE

   Ba tuỳ chọn BẮT BUỘC phải bật, nếu thiếu sẽ lỗi khi chạy file 07:
     rpc / rpc out            -> cho phép gọi thủ tục ở site kia
     remote proc transaction promotion -> cho phép giao tác cục bộ TỰ ĐỘNG
                                 NÂNG CẤP thành giao tác phân tán qua MS DTC
   ---------------------------------------------------------------------------- */
DECLARE @DanhSachSite TABLE (TenInstance SYSNAME);
INSERT INTO @DanhSachSite (TenInstance)
VALUES (@MayChu + N'\KHO_A'), (@MayChu + N'\KHO_B'), (@MayChu + N'\KHO_C');

DECLARE @Dich SYSNAME;
DECLARE cur CURSOR FOR
    SELECT TenInstance FROM @DanhSachSite WHERE TenInstance <> @SiteToi;
OPEN cur;
FETCH NEXT FROM cur INTO @Dich;

WHILE @@FETCH_STATUS = 0
BEGIN
    -- Xoá link cũ nếu đã tồn tại, để script chạy lại được nhiều lần
    IF EXISTS (SELECT 1 FROM sys.servers WHERE name = @Dich AND is_linked = 1)
    BEGIN
        EXEC sp_dropserver @server = @Dich, @droplogins = 'droplogins';
        PRINT N'  Đã xoá link cũ : ' + @Dich;
    END

    EXEC sp_addlinkedserver
         @server      = @Dich,
         @srvproduct  = N'',
         @provider    = N'MSOLEDBSQL',
         @datasrc     = @Dich;

    EXEC sp_addlinkedsrvlogin
         @rmtsrvname  = @Dich,
         @useself     = N'false',
         @locallogin  = NULL,
         @rmtuser     = @TaiKhoan,
         @rmtpassword = @MatKhau;

    EXEC sp_serveroption @Dich, N'rpc',      N'true';
    EXEC sp_serveroption @Dich, N'rpc out',  N'true';
    EXEC sp_serveroption @Dich, N'remote proc transaction promotion', N'true';
    EXEC sp_serveroption @Dich, N'collation compatible', N'true';
    EXEC sp_serveroption @Dich, N'data access', N'true';

    PRINT N'  ĐÃ TẠO LINK  : ' + @SiteToi + N'  ->  ' + @Dich;

    FETCH NEXT FROM cur INTO @Dich;
END
CLOSE cur;
DEALLOCATE cur;
GO

/* ----------------------------------------------------------------------------
   3. KIỂM TRA DANH SÁCH LINK ĐÃ TẠO
   ---------------------------------------------------------------------------- */
PRINT N'';
PRINT N'=== DANH SÁCH LINKED SERVER TẠI ' + @@SERVERNAME + N' ===';
GO

SELECT s.name                AS LinkedServer,
       s.product             AS SanPham,
       s.provider            AS Provider,
       s.data_source         AS ChuoiKetNoi,
       s.is_rpc_out_enabled  AS RPC_Out,
       s.is_remote_proc_transaction_promotion_enabled AS TuDongNangCap_DTC
FROM   sys.servers s
WHERE  s.is_linked = 1
ORDER BY s.name;
GO

/* ----------------------------------------------------------------------------
   4. KIỂM CHỨNG KẾT NỐI THỰC SỰ HOẠT ĐỘNG

   Gọi sang từng site kia hỏi "anh tên gì" - nếu trả lời đúng tên instance
   của site đó thì link đã thông.
   ---------------------------------------------------------------------------- */
PRINT N'';
PRINT N'=== KIỂM CHỨNG KẾT NỐI ===';
GO

DECLARE @Dich SYSNAME, @sql NVARCHAR(500);
DECLARE cur2 CURSOR FOR SELECT name FROM sys.servers WHERE is_linked = 1 ORDER BY name;
OPEN cur2;
FETCH NEXT FROM cur2 INTO @Dich;

WHILE @@FETCH_STATUS = 0
BEGIN
    BEGIN TRY
        DECLARE @KetQua SYSNAME;
        SET @sql = N'SELECT @out = TenServer FROM OPENQUERY([' + @Dich
                 + N'], ''SELECT @@SERVERNAME AS TenServer'')';
        EXEC sp_executesql @sql, N'@out SYSNAME OUTPUT', @out = @KetQua OUTPUT;
        PRINT N'  [OK]  ' + @Dich + N'  -> trả lời: ' + @KetQua;
    END TRY
    BEGIN CATCH
        PRINT N'  [LỖI] ' + @Dich + N'  -> ' + ERROR_MESSAGE();
    END CATCH
    FETCH NEXT FROM cur2 INTO @Dich;
END
CLOSE cur2;
DEALLOCATE cur2;
GO

/* ----------------------------------------------------------------------------
   5. ĐỌC DỮ LIỆU THẬT TỪ SITE KHÁC
      -> đây là bằng chứng cho mục 3.5 và 3.7b của báo cáo
   ---------------------------------------------------------------------------- */
PRINT N'';
PRINT N'=== ĐỌC TỒN KHO CỦA CÁC SITE KHÁC QUA LINKED SERVER ===';
GO

DECLARE @MayChu SYSNAME = CAST(SERVERPROPERTY('MachineName') AS SYSNAME);
DECLARE @sql NVARCHAR(MAX) = N'';

SELECT @sql = @sql +
       CASE WHEN @sql = N'' THEN N'' ELSE N' UNION ALL ' END +
       N'SELECT MaKho, COUNT(*) AS SoDongTonKho, SUM(SoLuong) AS TongSoLuong FROM ['
       + s.name + N'].' + QUOTENAME(N'Kho' + RIGHT(s.name, 1))
       + N'.dbo.TonKho GROUP BY MaKho'
FROM   sys.servers s
WHERE  s.is_linked = 1;

-- thêm chính site này vào cho đủ 3 dòng
SET @sql = N'SELECT MaKho, COUNT(*) AS SoDongTonKho, SUM(SoLuong) AS TongSoLuong
             FROM ' + QUOTENAME(N'Kho' + RIGHT(@@SERVERNAME, 1)) + N'.dbo.TonKho GROUP BY MaKho
             UNION ALL ' + @sql + N' ORDER BY MaKho';

EXEC sp_executesql @sql;
GO

PRINT N'';
PRINT N'HOÀN TẤT. Nhớ chạy file này trên CẢ BA instance.';
GO

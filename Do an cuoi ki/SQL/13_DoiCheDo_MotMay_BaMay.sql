/* ============================================================================
   ĐỒ ÁN CUỐI KỲ - CSDL PHÂN TÁN - QUẢN LÝ KHO VẬT TƯ ĐA CHI NHÁNH
   ----------------------------------------------------------------------------
   FILE 13 : CHUYỂN QUA LẠI GIỮA HAI CHẾ ĐỘ

       MOTMAY  - ba thể hiện trên chính máy này   -> tập dượt một mình
       BAMAY   - ba máy vật lý qua ZeroTier        -> hôm demo thật

   CHẠY TẠI : chỉ máy KHO_A là đủ cho việc tập dượt.
              Hôm demo thật thì cả ba máy chạy file 11 như cũ.

   ----------------------------------------------------------------------------
   VÌ SAO LÀM ĐƯỢC

   Linked Server tách làm hai phần rời nhau:
       @server   = TÊN GỌI       -> luôn giữ 'Mignon\KHO_B', 'Mignon\KHO_C'
       @datasrc  = ĐỊA CHỈ THẬT  -> thứ duy nhất đổi giữa hai chế độ

   Mọi tập lệnh 04-10 và phần mềm web gọi theo TÊN GỌI, nên không biết và
   không cần biết địa chỉ đang trỏ đi đâu. Đổi chế độ không phải sửa dòng nào.
   ============================================================================ */


/* ############################################################################
   PHẦN 0 - CHỌN CHẾ ĐỘ      ⚠️ SỬA ĐÚNG MỘT DÒNG DƯỚI ĐÂY
   ############################################################################ */
USE master;
GO

DECLARE @CheDo VARCHAR(10) = 'MOTMAY';      -- <<< 'MOTMAY' hoặc 'BAMAY'

/* ------------------------------------------------------------------------- */
DECLARE @DiaChi_B NVARCHAR(60), @DiaChi_C NVARCHAR(60);

IF @CheDo = 'MOTMAY'
BEGIN
    SET @DiaChi_B = N'localhost,1441';       -- thể hiện KHO_B ngay trên máy này
    SET @DiaChi_C = N'localhost,1442';       -- thể hiện KHO_C ngay trên máy này
END
ELSE IF @CheDo = 'BAMAY'
BEGIN
    SET @DiaChi_B = N'10.91.229.252,1441';   -- máy Admin-PC qua ZeroTier
    SET @DiaChi_C = N'10.91.229.121,1442';   -- máy GiaBinh  qua ZeroTier
END
ELSE
BEGIN
    RAISERROR (N'Chế độ phải là MOTMAY hoặc BAMAY. Sửa lại dòng @CheDo rồi chạy lại.', 16, 1);
    RETURN;
END

PRINT N'';
PRINT N'════════════════════════════════════════════════════════════════';
PRINT N'  ĐANG CHUYỂN SANG CHẾ ĐỘ: ' + @CheDo;
PRINT N'════════════════════════════════════════════════════════════════';

DECLARE @TaiKhoan NVARCHAR(50) = N'sa';
DECLARE @MatKhau  NVARCHAR(50) = N'123';

DECLARE @Site TABLE (TenLink NVARCHAR(128), DiaChi NVARCHAR(60));
INSERT INTO @Site VALUES
    (N'Mignon\KHO_B', @DiaChi_B),
    (N'Mignon\KHO_C', @DiaChi_C);

DECLARE @Link NVARCHAR(128), @Dia NVARCHAR(60);
DECLARE cur CURSOR LOCAL FAST_FORWARD FOR SELECT TenLink, DiaChi FROM @Site;
OPEN cur;
FETCH NEXT FROM cur INTO @Link, @Dia;

WHILE @@FETCH_STATUS = 0
BEGIN
    /* Gỡ link cũ. Khác file 11, ở đây KIỂM TRA lỗi thật sự thay vì in bừa
       dòng báo thành công - file 11 từng che mất lỗi kiểu này suốt một buổi. */
    IF EXISTS (SELECT 1 FROM sys.servers WHERE name = @Link AND is_linked = 1)
    BEGIN
        BEGIN TRY
            EXEC sp_dropserver @server = @Link, @droplogins = 'droplogins';
            PRINT N'   • Đã gỡ link cũ: ' + @Link;
        END TRY
        BEGIN CATCH
            PRINT N'   ✘ KHÔNG GỠ ĐƯỢC ' + @Link + N': ' + ERROR_MESSAGE();
            PRINT N'     -> Thường do replication còn giữ nó làm Subscriber.';
            PRINT N'        Chạy 00_ResetToanBo.sql trước rồi chạy lại file này.';
            CLOSE cur; DEALLOCATE cur;
            RETURN;
        END CATCH
    END

    EXEC sp_addlinkedserver
         @server = @Link, @srvproduct = N'', @provider = N'MSOLEDBSQL', @datasrc = @Dia;

    EXEC sp_addlinkedsrvlogin
         @rmtsrvname = @Link, @useself = N'False',
         @rmtuser = @TaiKhoan, @rmtpassword = @MatKhau;

    EXEC sp_serveroption @Link, N'data access', N'true';
    EXEC sp_serveroption @Link, N'rpc',         N'true';
    EXEC sp_serveroption @Link, N'rpc out',     N'true';
    EXEC sp_serveroption @Link, N'remote proc transaction promotion', N'true';
    EXEC sp_serveroption @Link, N'collation compatible', N'true';
    EXEC sp_serveroption @Link, N'connect timeout', N'30';

    PRINT N'   ✔ ' + @Link + N'  ->  ' + @Dia;

    FETCH NEXT FROM cur INTO @Link, @Dia;
END
CLOSE cur; DEALLOCATE cur;
GO


/* ############################################################################
   PHẦN 1 - THỬ HAI ĐƯỜNG LIÊN KẾT NGAY

   Đừng tin dòng chữ "đã tạo xong" ở trên. Phần này gọi thật sang hai site và
   đọc tên máy bên đó về - đó mới là bằng chứng.
   ############################################################################ */
SET NOCOUNT ON;

DECLARE @KetQua TABLE (LinkedServer NVARCHAR(128), TrangThai NVARCHAR(200));
DECLARE @L NVARCHAR(128);

DECLARE cur2 CURSOR LOCAL FAST_FORWARD FOR
    SELECT name FROM sys.servers WHERE is_linked = 1 ORDER BY name;
OPEN cur2;
FETCH NEXT FROM cur2 INTO @L;

WHILE @@FETCH_STATUS = 0
BEGIN
    BEGIN TRY
        DECLARE @sql NVARCHAR(MAX) =
            N'SELECT @ten = May FROM OPENQUERY(' + QUOTENAME(@L) +
            N', ''SELECT CAST(SERVERPROPERTY(''''MachineName'''') AS NVARCHAR(40)) May'')';
        DECLARE @ten NVARCHAR(40);
        EXEC sp_executesql @sql, N'@ten NVARCHAR(40) OUTPUT', @ten = @ten OUTPUT;
        INSERT INTO @KetQua VALUES (@L, N'THÔNG — máy bên kia tên: ' + @ten);
    END TRY
    BEGIN CATCH
        INSERT INTO @KetQua VALUES (@L, N'HỎNG — ' + ERROR_MESSAGE());
    END CATCH
    FETCH NEXT FROM cur2 INTO @L;
END
CLOSE cur2; DEALLOCATE cur2;

SELECT LinkedServer, TrangThai FROM @KetQua ORDER BY LinkedServer;

SELECT name AS TenGoi, data_source AS DiaChiThat
FROM   sys.servers WHERE is_linked = 1 ORDER BY name;
GO


/* ############################################################################
   PHẦN 2 - CẬP NHẬT BẢNG Kho

   Cột ServerName chứa TÊN GỌI Linked Server, không phải tên máy thật, nên
   KHÔNG đổi theo chế độ. Phần này chỉ để kiểm tra lại cho chắc.
   ############################################################################ */
USE KhoA;
GO

UPDATE Kho SET ServerName = N'Mignon\KHO_A' WHERE MaKho = 'KHO_A';
UPDATE Kho SET ServerName = N'Mignon\KHO_B' WHERE MaKho = 'KHO_B';
UPDATE Kho SET ServerName = N'Mignon\KHO_C' WHERE MaKho = 'KHO_C';

SELECT MaKho, TenKho, ServerName AS TenGoi_LinkedServer FROM Kho ORDER BY MaKho;
GO

PRINT N'';
PRINT N'>>> Xong. Bước tiếp theo: chạy 07b_ResetDeChupLaiAnh.sql để đưa số liệu';
PRINT N'    về mốc chuẩn, rồi mở 07_DieuChuyen_GiaoTacPhanTan.sql mà tập.  <<<';
GO

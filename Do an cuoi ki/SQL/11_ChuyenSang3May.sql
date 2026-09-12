/* ============================================================================
   ĐỒ ÁN CUỐI KỲ - CSDL PHÂN TÁN - QUẢN LÝ KHO VẬT TƯ ĐA CHI NHÁNH
   ----------------------------------------------------------------------------
   FILE 11 : CHUYỂN HỆ THỐNG TỪ 1 MÁY SANG 3 MÁY VẬT LÝ

   Dùng khi đem KHO_B sang máy bạn thứ nhất, KHO_C sang máy bạn thứ hai,
   ba máy nối nhau qua mạng riêng ảo ZeroTier.

   ĐỌC KÈM: HUONG_DAN_TRIEN_KHAI_3_MAY_THAT.md  (các bước ngoài SQL)

   ----------------------------------------------------------------------------
   Ý TƯỞNG CỐT LÕI - VÌ SAO KHÔNG PHẢI SỬA 10 SCRIPT KIA

   Mười script từ 01 đến 10 gọi nhau bằng tên  [Mignon\KHO_B]  và  [Mignon\KHO_C].
   Nếu đem sang máy khác, tên máy sẽ thành LAPTOP-BAN1\KHO_B - khác hoàn toàn.

   Cách xử lý: Linked Server có HAI phần tách rời nhau
        @server   = TÊN GỌI  ->  giữ nguyên 'Mignon\KHO_B'
        @datasrc  = ĐỊA CHỈ THẬT ->  đổi thành '10.147.20.51,1441'

   Nghĩa là ta giữ nguyên CÁI TÊN mà mọi script đang dùng, chỉ đổi ĐỊA CHỈ mà
   cái tên đó trỏ tới. Giống như đổi số nhà trong danh bạ nhưng vẫn gọi người
   đó bằng tên cũ.

   => Toàn bộ script 04-10 chạy y nguyên, KHÔNG sửa một dòng nào.
      Đây chính là TRONG SUỐT VỊ TRÍ (location transparency) ở mức hạ tầng,
      rất đáng nêu trong báo cáo và khi thuyết trình.
   ============================================================================ */


/* ############################################################################
   ############################################################################
   PHẦN 0 - KHAI BÁO THÔNG SỐ    ⚠️ SỬA ĐÚNG 6 DÒNG DƯỚI ĐÂY RỒI MỚI CHẠY
   ############################################################################

   Lấy IP ảo ở đâu:
     Vào  https://my.zerotier.com  -> bấm vào network của nhóm -> kéo xuống
     mục Members -> cột "Managed IPs" của từng máy.

   Lấy tên máy chủ thật ở đâu:
     Mỗi bạn mở SSMS trên máy mình, chạy:   SELECT @@SERVERNAME
     rồi đọc kết quả cho bạn ghi lại.
   ############################################################################ */

DECLARE @IP_KhoA      NVARCHAR(50)  = N'10.147.20.35';   -- <<< SỬA: IP ảo máy bạn
DECLARE @IP_KhoB      NVARCHAR(50)  = N'10.147.20.51';   -- <<< SỬA: IP ảo máy bạn thứ nhất
DECLARE @IP_KhoC      NVARCHAR(50)  = N'10.147.20.77';   -- <<< SỬA: IP ảo máy bạn thứ hai

DECLARE @TenMay_KhoA  NVARCHAR(128) = N'MIGNON\KHO_A';        -- <<< SỬA nếu khác
DECLARE @TenMay_KhoB  NVARCHAR(128) = N'LAPTOP-BAN1\KHO_B';   -- <<< SỬA
DECLARE @TenMay_KhoC  NVARCHAR(128) = N'LAPTOP-BAN2\KHO_C';   -- <<< SỬA

/* Cổng cố định do script BatTCPIP_VaFirewall.ps1 gán - giữ nguyên */
DECLARE @Cong_KhoA INT = 1440, @Cong_KhoB INT = 1441, @Cong_KhoC INT = 1442;

/* Tài khoản dùng cho Linked Server */
DECLARE @TaiKhoan NVARCHAR(50) = N'sa';
DECLARE @MatKhau  NVARCHAR(50) = N'123';

-- Ghi nhớ để các phần sau dùng lại
DECLARE @KhoNay CHAR(5) = dbo.fn_MaKhoHienTai();

PRINT N'';
PRINT N'════════════════════════════════════════════════════════════════════';
PRINT N'  CHUYỂN SANG MÔ HÌNH 3 MÁY - đang chạy tại site: ' + @KhoNay;
PRINT N'  Máy chủ thật của site này: ' + @@SERVERNAME;
PRINT N'════════════════════════════════════════════════════════════════════';
GO


/* ############################################################################
   PHẦN 1 - TRỎ LẠI HAI LINKED SERVER SANG ĐỊA CHỈ MỚI

   Chạy ở CẢ BA MÁY. Mỗi máy tự bỏ qua chính nó.
   ############################################################################ */
USE master;
GO

DECLARE @IP_KhoA NVARCHAR(50) = N'10.147.20.35';   -- <<< SỬA giống PHẦN 0
DECLARE @IP_KhoB NVARCHAR(50) = N'10.147.20.51';   -- <<< SỬA
DECLARE @IP_KhoC NVARCHAR(50) = N'10.147.20.77';   -- <<< SỬA
DECLARE @TaiKhoan NVARCHAR(50) = N'sa', @MatKhau NVARCHAR(50) = N'123';

DECLARE @KhoNay CHAR(5) = (SELECT TOP 1 MaKho FROM
                           (SELECT 'KHO_' + UPPER(RIGHT(DB_NAME(),1)) AS MaKho) x);

/* Bảng mô tả ba site: tên gọi Linked Server (giữ nguyên) + địa chỉ mới */
DECLARE @Site TABLE (MaKho CHAR(5), TenLink NVARCHAR(128), DiaChi NVARCHAR(80));
INSERT INTO @Site VALUES
    ('KHO_A', N'Mignon\KHO_A', @IP_KhoA + N',1440'),
    ('KHO_B', N'Mignon\KHO_B', @IP_KhoB + N',1441'),
    ('KHO_C', N'Mignon\KHO_C', @IP_KhoC + N',1442');

DECLARE @Ma CHAR(5), @Link NVARCHAR(128), @Dia NVARCHAR(80);
DECLARE cur CURSOR FOR
    SELECT MaKho, TenLink, DiaChi FROM @Site
    WHERE  MaKho <> 'KHO_' + UPPER(RIGHT(DB_NAME(),1));   -- bỏ qua chính mình
OPEN cur;
FETCH NEXT FROM cur INTO @Ma, @Link, @Dia;

WHILE @@FETCH_STATUS = 0
BEGIN
    -- Xoá link cũ nếu có (link cũ đang trỏ vào máy Mignon, không còn đúng)
    IF EXISTS (SELECT 1 FROM sys.servers WHERE name = @Link AND is_linked = 1)
    BEGIN
        EXEC sp_dropserver @server = @Link, @droplogins = 'droplogins';
        PRINT N'   • Đã gỡ link cũ: ' + @Link;
    END

    /* TẠO LẠI: TÊN giữ nguyên, ĐỊA CHỈ trỏ sang IP ảo của máy bạn */
    EXEC sp_addlinkedserver
         @server     = @Link,              -- tên gọi - mọi script đang dùng tên này
         @srvproduct = N'',
         @provider   = N'MSOLEDBSQL',
         @datasrc    = @Dia;               -- địa chỉ thật - IP ảo ZeroTier + cổng

    EXEC sp_addlinkedsrvlogin
         @rmtsrvname  = @Link,
         @useself     = N'False',
         @rmtuser     = @TaiKhoan,
         @rmtpassword = @MatKhau;

    -- Bốn tuỳ chọn bắt buộc, thiếu cái nào hỏng cái đó
    EXEC sp_serveroption @Link, N'data access',  N'true';   -- đọc dữ liệu
    EXEC sp_serveroption @Link, N'rpc',          N'true';
    EXEC sp_serveroption @Link, N'rpc out',      N'true';   -- gọi thủ tục từ xa
    EXEC sp_serveroption @Link, N'remote proc transaction promotion', N'true';  -- 2PC
    EXEC sp_serveroption @Link, N'collation compatible', N'true';
    EXEC sp_serveroption @Link, N'connect timeout', N'30';  -- mạng VPN chậm hơn LAN
    EXEC sp_serveroption @Link, N'query timeout',   N'120';

    PRINT N'   ✔ ' + @Link + N'  ->  ' + @Dia;

    FETCH NEXT FROM cur INTO @Ma, @Link, @Dia;
END
CLOSE cur; DEALLOCATE cur;
GO

-- Kiểm chứng: cột NguonDuLieu giờ phải là IP ảo, không còn là tên máy
SELECT  name                    AS TenGoi_LinkedServer,
        data_source             AS DiaChiThat,
        is_data_access_enabled  AS DocDuLieu,
        is_rpc_out_enabled      AS GoiThuTuc,
        is_remote_proc_transaction_promotion_enabled AS NangLen2PC
FROM    sys.servers WHERE is_linked = 1;
GO


/* ############################################################################
   PHẦN 2 - THỬ TỪNG ĐƯỜNG LIÊN KẾT

   Chạy ở CẢ BA MÁY. Phải thấy "✔ THÔNG" cho cả hai link thì mới đi tiếp.
   ############################################################################ */
DECLARE @Link NVARCHAR(128), @Loi NVARCHAR(400);
DECLARE @KQ TABLE (LinkedServer NVARCHAR(128), TrangThai NVARCHAR(400));

DECLARE c2 CURSOR FOR SELECT name FROM sys.servers WHERE is_linked = 1 ORDER BY name;
OPEN c2; FETCH NEXT FROM c2 INTO @Link;
WHILE @@FETCH_STATUS = 0
BEGIN
    BEGIN TRY
        EXEC sys.sp_testlinkedserver @Link;
        INSERT INTO @KQ VALUES (@Link, N'✔ THÔNG');
    END TRY
    BEGIN CATCH
        SET @Loi = LEFT(ERROR_MESSAGE(), 300);
        INSERT INTO @KQ VALUES (@Link, N'✘ KHÔNG THÔNG: ' + @Loi);
    END CATCH
    FETCH NEXT FROM c2 INTO @Link;
END
CLOSE c2; DEALLOCATE c2;

SELECT * FROM @KQ;
GO

/*  NẾU BÁO "✘ KHÔNG THÔNG" thì lần lượt kiểm tra:

    1. Máy kia đã bật ZeroTier chưa, có online trên my.zerotier.com không
    2. Máy kia đã chạy BatTCPIP_VaFirewall.ps1 chưa (TCP/IP + firewall)
    3. Thử từ PowerShell máy này:
           Test-NetConnection 10.147.20.51 -Port 1441
       PingSucceeded phải True và TcpTestSucceeded phải True
    4. Mật khẩu sa ở máy kia có đúng là '123' không
    5. Máy kia đã bật SQL Server Authentication chưa (không chỉ Windows Auth)
    ------------------------------------------------------------------------ */


/* ############################################################################
   PHẦN 3 - CẬP NHẬT BẢNG Kho

   ⚠️ CHỈ CHẠY Ở MÁY KHO_A. Hai máy kia sẽ tự nhận qua replication.

   Cột ServerName được dùng bởi sp_DieuChuyenVatTu và sp_TonKhoToanHeThong để
   dựng câu lệnh động. Nó phải chứa TÊN GỌI Linked Server - tức là giữ nguyên
   'Mignon\KHO_x' - chứ KHÔNG phải tên máy thật.
   ############################################################################ */
USE KhoA;
GO

UPDATE Kho SET ServerName = N'Mignon\KHO_A' WHERE MaKho = 'KHO_A';
UPDATE Kho SET ServerName = N'Mignon\KHO_B' WHERE MaKho = 'KHO_B';
UPDATE Kho SET ServerName = N'Mignon\KHO_C' WHERE MaKho = 'KHO_C';

SELECT MaKho, TenKho, ServerName AS TenGoi_LinkedServer FROM Kho;
GO


/* ############################################################################
   PHẦN 4 - KIỂM THỬ TOÀN HỆ THỐNG TRÊN 3 MÁY     📷 ẢNH MỤC 3.2

   Chạy ở MÁY KHO_A sau khi PHẦN 1-3 xong ở cả ba máy.
   ############################################################################ */
USE KhoA;
SET NOCOUNT ON;
GO

PRINT N'';
PRINT N'╔══════════════════════════════════════════════════════════════════╗';
PRINT N'║  KIỂM THỬ HỆ THỐNG 3 MÁY VẬT LÝ QUA MẠNG ẢO ZEROTIER             ║';
PRINT N'╚══════════════════════════════════════════════════════════════════╝';
GO

-- 4.1  Ba máy chủ có đúng là ba máy VẬT LÝ khác nhau không
SELECT N'KHO_A' AS Site, @@SERVERNAME AS TenMayChuThat,
       CAST(SERVERPROPERTY('MachineName') AS NVARCHAR(60)) AS TenMayTinh
UNION ALL
SELECT N'KHO_B', s.Srv, s.May FROM OPENQUERY([Mignon\KHO_B],
       'SELECT Srv = @@SERVERNAME, May = CAST(SERVERPROPERTY(''MachineName'') AS NVARCHAR(60))') s
UNION ALL
SELECT N'KHO_C', s.Srv, s.May FROM OPENQUERY([Mignon\KHO_C],
       'SELECT Srv = @@SERVERNAME, May = CAST(SERVERPROPERTY(''MachineName'') AS NVARCHAR(60))') s;
GO

/*  ĐÂY LÀ BẢNG QUAN TRỌNG NHẤT CỦA CẢ ĐỒ ÁN.
    Ba dòng, ba tên máy tính KHÁC NHAU -> chứng minh hệ thống đang chạy trên
    ba máy vật lý riêng biệt, không phải ba instance trên cùng một máy.       */

-- 4.2  Đường truyền có thật sự đi qua mạng không
SELECT  N'Kết nối hiện tại' AS Muc,
        net_transport       AS GiaoThuc,
        local_net_address   AS DiaChi_MayChu,
        local_tcp_port      AS Cong,
        client_net_address  AS DiaChi_MayKhach
FROM    sys.dm_exec_connections WHERE session_id = @@SPID;
GO

-- 4.3  Truy vấn phân tán: gom tồn kho từ ba máy vật lý
SELECT MaKho, COUNT(*) AS SoMatHang, SUM(SoLuong) AS TongSoLuong
FROM   dbo.v_TonKho_ToanHeThong
GROUP BY MaKho
UNION ALL
SELECT N'  *  ', COUNT(*), SUM(SoLuong) FROM dbo.v_TonKho_ToanHeThong
ORDER BY MaKho;
GO

-- 4.4  Giao tác phân tán qua mạng - phép thử nặng nhất
--      Nếu chạy được nghĩa là MS DTC đã bắt tay thành công GIỮA HAI MÁY THẬT.
DECLARE @dc CHAR(6);
BEGIN TRY
    EXEC dbo.sp_DieuChuyenVatTu
         @MaKhoDich = 'KHO_B', @MaVT = 'VT009', @SoLuong = 10,
         @NguoiLap  = N'Kiểm thử 3 máy', @GhiChu = N'Thử 2PC qua ZeroTier',
         @MaDC = @dc OUTPUT;
    PRINT N'✔ GIAO TÁC PHÂN TÁN QUA MẠNG THÀNH CÔNG - phiếu ' + @dc;
    PRINT N'   MS DTC đã điều phối commit hai pha giữa HAI MÁY VẬT LÝ.';
END TRY
BEGIN CATCH
    PRINT N'✘ THẤT BẠI: ' + ERROR_MESSAGE();
    PRINT N'';
    PRINT N'   Lỗi hay gặp nhất ở bước này là MS DTC chưa mở cho mạng.';
    PRINT N'   Xem mục "Cấu hình MS DTC" trong HUONG_DAN_TRIEN_KHAI_3_MAY_THAT.md';
END CATCH
GO

-- 4.5  Đối chiếu sau điều chuyển
SELECT * FROM dbo.v_TonKho_AB WHERE MaVT = 'VT009';
GO


/* ============================================================================
   PHƯƠNG ÁN QUAY VỀ 1 MÁY

   Nếu hôm demo mạng trục trặc, chạy lại file 05_LinkedServer.sql ở cả ba
   instance trên máy bạn là hệ thống trở về mô hình 1 máy như cũ, dùng được ngay.
   Toàn bộ ảnh minh chứng đã chụp vẫn còn nguyên giá trị.
   ============================================================================ */

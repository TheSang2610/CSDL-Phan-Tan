/* ============================================================================
   ĐỒ ÁN CUỐI KỲ - CSDL PHÂN TÁN - QUẢN LÝ KHO VẬT TƯ ĐA CHI NHÁNH
   ----------------------------------------------------------------------------
   FILE 06 : TẠO PUBLICATION - ĐỒNG BỘ DANH MỤC VẬT TƯ   (mục 3.6 của báo cáo)

   CHẠY TẠI : CHỈ chạy trên instance MIGNON\KHO_A (Kho Trung tâm)
              Script tự cấu hình luôn hai Subscriber KHO_B và KHO_C.

   ----------------------------------------------------------------------------
   MÔ HÌNH NHÂN BẢN

                    MIGNON\KHO_A  (Kho Trung tâm)
                    ┌──────────────────────────────┐
                    │  PUBLISHER  +  DISTRIBUTOR   │
                    │  Publication: PUB_DanhMuc    │
                    │  Article: NhaCungCap         │
                    │           VatTu              │
                    │           Kho                │
                    └───────┬──────────────┬───────┘
                            │              │
                Push Subscription   Push Subscription
                            │              │
                            ▼              ▼
                   MIGNON\KHO_B     MIGNON\KHO_C
                   (SUBSCRIBER)     (SUBSCRIBER)

   ----------------------------------------------------------------------------
   VÌ SAO CHỌN TRANSACTIONAL REPLICATION (không phải Merge)

   Danh mục vật tư CHỈ được sửa ở MỘT nơi duy nhất là Kho Trung tâm; hai kho
   còn lại chỉ đọc. Không bao giờ có xung đột ghi => Transactional là đủ, nhẹ
   hơn và độ trễ thấp hơn Merge. Merge chỉ cần khi nhiều site cùng sửa một dòng.

   ----------------------------------------------------------------------------
   VÌ SAO DÙNG @sync_type = 'replication support only'

   Ba site đã được nạp CÙNG MỘT bộ danh mục giống hệt nhau bởi script 01-03,
   nên không cần truyền snapshot khởi tạo => tiết kiệm băng thông.

   Quan trọng hơn: bảng TonKho ở Subscriber có KHÓA NGOẠI trỏ tới VatTu. Nếu
   dùng snapshot thông thường, bước khởi tạo sẽ XÓA sạch bảng VatTu ở Subscriber
   trước khi nạp lại - thao tác đó VI PHẠM khóa ngoại và làm hỏng quá trình đồng
   bộ. Phương án 'replication support only' chỉ tạo các thủ tục đồng bộ ở
   Subscriber, giữ nguyên dữ liệu và ràng buộc sẵn có.
   ============================================================================ */

SET NOCOUNT ON;
GO

/* ############################################################################
   PHẦN 1 - CẤU HÌNH DISTRIBUTOR
   Kho Trung tâm đóng luôn vai trò Distributor (local distributor).
   ############################################################################ */
USE master;
GO

DECLARE @distributor SYSNAME = @@SERVERNAME;

IF NOT EXISTS (SELECT 1 FROM sys.servers WHERE name = @distributor AND is_distributor = 1)
BEGIN
    EXEC sp_adddistributor @distributor = @distributor, @password = N'Repl@2026';
    PRINT N'[1/6] Đã khai báo Distributor: ' + @distributor;
END
ELSE
    PRINT N'[1/6] Distributor đã có sẵn: ' + @distributor;
GO

-- CSDL phân phối: nơi lưu các lệnh chờ đẩy xuống Subscriber
IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = N'distribution')
BEGIN
    EXEC sp_adddistributiondb
         @database      = N'distribution',
         @data_folder   = N'D:\SQLServer\KhoA\MSSQL16.KHO_A\MSSQL\DATA',
         @log_folder    = N'D:\SQLServer\KhoA\MSSQL16.KHO_A\MSSQL\DATA',
         @security_mode = 1;
    PRINT N'[2/6] Đã tạo CSDL distribution';
END
ELSE
    PRINT N'[2/6] CSDL distribution đã có sẵn';
GO

-- Khai báo Publisher dùng Distributor này, kèm thư mục chứa snapshot
DECLARE @publisher SYSNAME = @@SERVERNAME;

IF NOT EXISTS (SELECT 1 FROM msdb.dbo.MSdistpublishers WHERE name = @publisher)
BEGIN
    EXEC sp_adddistpublisher
         @publisher         = @publisher,
         @distribution_db   = N'distribution',
         @security_mode     = 1,
         @working_directory = N'D:\SQLServer\KhoA\MSSQL16.KHO_A\MSSQL\ReplData',
         @trusted           = N'false',
         @thirdparty_flag   = 0,
         @publisher_type    = N'MSSQLSERVER';
    PRINT N'[3/6] Đã gắn Publisher vào Distributor';
END
ELSE
    PRINT N'[3/6] Publisher đã gắn vào Distributor từ trước';
GO

/* ############################################################################
   PHẦN 2 - BẬT CHẾ ĐỘ XUẤT BẢN CHO CSDL KhoA
   ############################################################################ */
USE master;
GO

IF (SELECT is_published FROM sys.databases WHERE name = N'KhoA') = 0
BEGIN
    EXEC sp_replicationdboption
         @dbname  = N'KhoA',
         @optname = N'publish',
         @value   = N'true';
    PRINT N'[4/6] Đã bật chế độ publish cho CSDL KhoA';
END
ELSE
    PRINT N'[4/6] CSDL KhoA đã bật publish từ trước';
GO

/* Log Reader Agent: đọc nhật ký giao dịch của KhoA, chuyển các lệnh
   INSERT/UPDATE/DELETE trên article sang CSDL distribution.               */
USE KhoA;
GO

IF NOT EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name LIKE N'%KhoA%LogReader%')
BEGIN
    EXEC sp_addlogreader_agent
         @job_login              = NULL,
         @job_password           = NULL,
         @publisher_security_mode = 1;
    PRINT N'      Đã tạo Log Reader Agent';
END
GO

/* ############################################################################
   PHẦN 3 - TẠO PUBLICATION VÀ CÁC ARTICLE
   ############################################################################ */
USE KhoA;
GO

/* Dọn sạch cấu hình cũ để script chạy lại được nhiều lần.
   PHẢI xoá Subscription TRƯỚC rồi mới xoá được Publication - nếu làm ngược
   sẽ báo lỗi 14005 và cấu hình cũ vẫn còn nguyên.                          */
IF EXISTS (SELECT 1 FROM syspublications WHERE name = N'PUB_DanhMuc')
BEGIN
    DECLARE @MayChuCu SYSNAME = CAST(SERVERPROPERTY('MachineName') AS SYSNAME);

    BEGIN TRY
        EXEC sp_dropsubscription @publication = N'PUB_DanhMuc', @article = N'all',
             @subscriber = @MayChuCu, @destination_db = N'KhoB';
    END TRY BEGIN CATCH END CATCH

    DECLARE @SubB SYSNAME = @MayChuCu + N'\KHO_B';
    DECLARE @SubC SYSNAME = @MayChuCu + N'\KHO_C';

    BEGIN TRY
        EXEC sp_dropsubscription @publication = N'PUB_DanhMuc', @article = N'all',
             @subscriber = @SubB, @destination_db = N'KhoB';
    END TRY BEGIN CATCH END CATCH

    BEGIN TRY
        EXEC sp_dropsubscription @publication = N'PUB_DanhMuc', @article = N'all',
             @subscriber = @SubC, @destination_db = N'KhoC';
    END TRY BEGIN CATCH END CATCH

    EXEC sp_droppublication @publication = N'PUB_DanhMuc';
    PRINT N'      Đã xoá Subscription và Publication cũ để tạo lại';
END
GO

EXEC sp_addpublication
     @publication              = N'PUB_DanhMuc',
     @description              = N'Dong bo danh muc vat tu, nha cung cap va danh sach kho',
     @sync_method              = N'concurrent',
     @retention                = 0,
     @allow_push               = N'true',
     @allow_pull               = N'true',
     @allow_anonymous          = N'false',
     @enabled_for_internet     = N'false',
     @snapshot_in_defaultfolder = N'true',
     @compress_snapshot        = N'false',
     @allow_subscription_copy  = N'false',
     @add_to_active_directory  = N'false',
     @repl_freq                = N'continuous',
     @status                   = N'active',
     @independent_agent        = N'true',
     @immediate_sync           = N'false',
     @allow_sync_tran          = N'false',
     @autogen_sync_procs       = N'false',
     @allow_queued_tran        = N'false',
     @allow_dts                = N'false',
     @replicate_ddl            = 1,
     @allow_initialize_from_backup = N'false',
     @enabled_for_p2p          = N'false',
     @enabled_for_het_sub      = N'false';
PRINT N'[5/6] Đã tạo Publication PUB_DanhMuc';
GO

-- Snapshot Agent (tạo job, không bắt buộc phải chạy vì dùng 'replication support only')
EXEC sp_addpublication_snapshot
     @publication             = N'PUB_DanhMuc',
     @frequency_type          = 1,      -- 1 = chạy một lần khi được gọi
     @frequency_interval      = 1,
     @frequency_relative_interval = 1,
     @frequency_recurrence_factor = 0,
     @frequency_subday        = 8,
     @frequency_subday_interval = 1,
     @active_start_date       = 0,
     @active_end_date         = 99991231,
     @job_login               = NULL,
     @job_password            = NULL,
     @publisher_security_mode = 1;
GO

/* --- Ba article: ba bảng danh mục dùng chung toàn hệ thống --------------- */
EXEC sp_addarticle
     @publication       = N'PUB_DanhMuc',
     @article           = N'NhaCungCap',
     @source_owner      = N'dbo',  @source_object    = N'NhaCungCap',
     @destination_owner = N'dbo',  @destination_table = N'NhaCungCap',
     @type              = N'logbased',
     @pre_creation_cmd  = N'none',       -- KHÔNG xoá bảng ở Subscriber
     @identityrangemanagementoption = N'manual',
     @schema_option     = 0x0000000008035FDF;
GO

EXEC sp_addarticle
     @publication       = N'PUB_DanhMuc',
     @article           = N'VatTu',
     @source_owner      = N'dbo',  @source_object    = N'VatTu',
     @destination_owner = N'dbo',  @destination_table = N'VatTu',
     @type              = N'logbased',
     @pre_creation_cmd  = N'none',
     @identityrangemanagementoption = N'manual',
     @schema_option     = 0x0000000008035FDF;
GO

EXEC sp_addarticle
     @publication       = N'PUB_DanhMuc',
     @article           = N'Kho',
     @source_owner      = N'dbo',  @source_object    = N'Kho',
     @destination_owner = N'dbo',  @destination_table = N'Kho',
     @type              = N'logbased',
     @pre_creation_cmd  = N'none',
     @identityrangemanagementoption = N'manual',
     @schema_option     = 0x0000000008035FDF;
PRINT N'      Đã thêm 3 article: NhaCungCap, VatTu, Kho';
GO

/* ############################################################################
   PHẦN 4 - TẠO SUBSCRIPTION CHO KHO_B VÀ KHO_C

   Dùng PUSH subscription: Distribution Agent chạy tại Distributor (KHO_A).
   Ưu điểm trong bài này: cả Log Reader lẫn Distribution Agent đều chạy dưới
   cùng một tài khoản dịch vụ SQLAgent$KHO_A nên không vướng quyền truy cập
   thư mục snapshot giữa các instance.
   ############################################################################ */
USE KhoA;
GO

DECLARE @MayChu SYSNAME = CAST(SERVERPROPERTY('MachineName') AS SYSNAME);
DECLARE @Sub SYSNAME, @SubDb SYSNAME;
DECLARE cur CURSOR FOR
    SELECT @MayChu + N'\KHO_B', N'KhoB'
    UNION ALL
    SELECT @MayChu + N'\KHO_C', N'KhoC';
OPEN cur;
FETCH NEXT FROM cur INTO @Sub, @SubDb;

WHILE @@FETCH_STATUS = 0
BEGIN
    IF EXISTS (SELECT 1 FROM syssubscriptions s
               JOIN sysarticles a ON a.artid = s.artid
               WHERE s.srvname = @Sub)
    BEGIN
        EXEC sp_dropsubscription @publication = N'PUB_DanhMuc',
             @article = N'all', @subscriber = @Sub, @destination_db = @SubDb;
        PRINT N'      Đã xoá subscription cũ của ' + @Sub;
    END

    EXEC sp_addsubscription
         @publication      = N'PUB_DanhMuc',
         @subscriber       = @Sub,
         @destination_db   = @SubDb,
         @subscription_type = N'Push',
         @sync_type        = N'replication support only',
         @article          = N'all',
         @update_mode      = N'read only',
         @subscriber_type  = 0;

    /* Distribution Agent chạy dưới tài khoản dịch vụ NT Service\SQLAgent$KHO_A.
       Tài khoản đó KHÔNG có login trên KHO_B / KHO_C nên nếu để
       @subscriber_security_mode = 1 (Windows Auth) sẽ báo:
           "The process could not connect to Subscriber 'Mignon\KHO_B'."
       => Dùng SQL Authentication bằng tài khoản 'sa', giống cách Linked Server
          đang xác thực ở file 05.                                            */
    EXEC sp_addpushsubscription_agent
         @publication             = N'PUB_DanhMuc',
         @subscriber              = @Sub,
         @subscriber_db           = @SubDb,
         @job_login               = NULL,
         @job_password            = NULL,
         @subscriber_security_mode = 0,
         @subscriber_login        = N'sa',
         @subscriber_password     = N'123',
         @frequency_type          = 64,     -- 64 = chạy liên tục khi Agent khởi động
         @frequency_interval      = 1,
         @frequency_subday        = 4,
         @frequency_subday_interval = 5,
         @active_start_date       = 0,
         @active_end_date         = 99991231,
         @enabled_for_syncmgr     = N'False',
         @dts_package_location    = N'Distributor';

    PRINT N'[6/6] Đã tạo Push Subscription: KHO_A  ->  ' + @Sub + N' (' + @SubDb + N')';

    FETCH NEXT FROM cur INTO @Sub, @SubDb;
END
CLOSE cur;
DEALLOCATE cur;
GO

/* ############################################################################
   PHẦN 5 - KIỂM TRA CẤU HÌNH
   ############################################################################ */
PRINT N'';
PRINT N'=================== KẾT QUẢ CẤU HÌNH NHÂN BẢN ===================';
GO

SELECT N'Distributor' AS HangMuc,
       CAST(SERVERPROPERTY('IsDistributor') AS VARCHAR(2))  AS GiaTri
UNION ALL
SELECT N'Publisher',  CAST(SERVERPROPERTY('IsPublisher') AS VARCHAR(2));
GO

USE KhoA;
SELECT p.name AS Publication, p.description AS MoTa,
       CASE p.repl_freq WHEN 0 THEN N'Continuous' ELSE N'Snapshot' END AS TanSuat,
       CASE p.status    WHEN 1 THEN N'Active'     ELSE N'Inactive'  END AS TrangThai
FROM   syspublications p;
GO

USE KhoA;
SELECT a.name AS Article, a.dest_table AS BangDich
FROM   sysarticles a
JOIN   syspublications p ON p.pubid = a.pubid
WHERE  p.name = N'PUB_DanhMuc';
GO

USE KhoA;
SELECT DISTINCT s.srvname AS Subscriber, s.dest_db AS CSDL_Dich,
       CASE s.status WHEN 2 THEN N'Active' WHEN 1 THEN N'Subscribed' ELSE N'Inactive' END AS TrangThai
FROM   syssubscriptions s;
GO

/* ############################################################################
   PHẦN 6 - BẬT LẠI 'data access' CHO CÁC LINKED SERVER   ⚠️ BẮT BUỘC

   VẤN ĐỀ ĐÃ GẶP THẬT KHI TRIỂN KHAI:
     Thủ tục sp_addsubscription ở PHẦN 4 tự tạo/ghi đè mục Linked Server của
     Subscriber tại Publisher, và nó TẮT tùy chọn 'data access' - vì replication
     giao tiếp bằng RPC riêng, không cần tới truy vấn phân tán.

     Hậu quả: mọi câu lệnh kiểu
         SELECT * FROM [Mignon\KHO_B].KhoB.dbo.VatTu
     đang chạy tốt ở file 05 bỗng báo lỗi:
         Msg 7411 - Server 'Mignon\KHO_B' is not configured for DATA ACCESS.

   => Sau khi cấu hình replication PHẢI bật lại tuỳ chọn này, nếu không phần
      truy vấn phân tán (mục 3.5 và 3.7) sẽ hỏng.
   ############################################################################ */
USE master;
GO

DECLARE @s SYSNAME;
DECLARE cur3 CURSOR FOR SELECT name FROM sys.servers WHERE is_linked = 1;
OPEN cur3;
FETCH NEXT FROM cur3 INTO @s;
WHILE @@FETCH_STATUS = 0
BEGIN
    EXEC sp_serveroption @s, N'data access', N'true';
    EXEC sp_serveroption @s, N'rpc',         N'true';
    EXEC sp_serveroption @s, N'rpc out',     N'true';
    -- Tuỳ chọn này cũng bị sp_addsubscription tắt mất. Thiếu nó thì lệnh gọi
    -- thủ tục ở máy từ xa KHÔNG tự động nâng lên giao tác phân tán (2PC),
    -- nghĩa là nửa việc ở máy kia sẽ không được rollback cùng máy này.
    EXEC sp_serveroption @s, N'remote proc transaction promotion', N'true';
    PRINT N'      Đã bật lại data access + 2PC cho Linked Server: ' + @s;
    FETCH NEXT FROM cur3 INTO @s;
END
CLOSE cur3;
DEALLOCATE cur3;
GO

SELECT name                   AS LinkedServer,
       is_data_access_enabled AS DataAccess,
       is_rpc_out_enabled     AS RpcOut,
       is_remote_proc_transaction_promotion_enabled AS NangLen2PC
FROM   sys.servers WHERE is_linked = 1;
GO

PRINT N'';
PRINT N'Xong. Chạy tiếp file 06b để KIỂM CHỨNG đồng bộ hoạt động.';
GO

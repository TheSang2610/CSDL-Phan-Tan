/* ============================================================================
   ĐỒ ÁN CUỐI KỲ - CSDL PHÂN TÁN - QUẢN LÝ KHO VẬT TƯ ĐA CHI NHÁNH
   ----------------------------------------------------------------------------
   FILE 00 : DỌN SẠCH NHÂN BẢN TRƯỚC KHI DỰNG LẠI TOÀN BỘ HỆ THỐNG

   ⚠️ ĐỌC KỸ TRƯỚC KHI CHẠY
      File này CHỈ dùng khi muốn XOÁ HẾT và làm lại từ đầu.
      Nếu chỉ muốn đưa dữ liệu demo về trạng thái gốc để chụp lại ảnh thì
      dùng  07b_ResetDeChupLaiAnh.sql  - nhẹ hơn nhiều, không mất gì cả.

   ----------------------------------------------------------------------------
   VÌ SAO CẦN FILE NÀY

   Script 01 mở đầu bằng lệnh DROP DATABASE KhoA. Nhưng khi KhoA đang làm
   Publisher của nhân bản thì SQL Server từ chối:

        Msg 3724 - Cannot drop the database 'KhoA' because it is being used
                   for replication.

   Phải gỡ nhân bản ra trước thì mới xoá được database. Đó là việc duy nhất
   file này làm.

   ----------------------------------------------------------------------------
   CHẠY Ở ĐÂU
      Chỉ chạy trên  MIGNON\KHO_A , chọn database  master  ở ô dropdown SSMS.
      Hai site KHO_B và KHO_C không cần chạy gì cả - chúng chỉ là Subscriber,
      xoá Publication ở đây là chúng tự rời ra.

   ----------------------------------------------------------------------------
   SAU KHI CHẠY FILE NÀY, DỰNG LẠI THEO ĐÚNG THỨ TỰ

      01_TaoCSDL_KhoA.sql          ->  tại KHO_A
      02_TaoCSDL_KhoB.sql          ->  tại KHO_B
      03_TaoCSDL_KhoC.sql          ->  tại KHO_C
      04_ThuTuc_NghiepVu.sql       ->  CẢ BA site
      05_LinkedServer.sql          ->  CẢ BA site
      06_Replication_DongBoDanhMuc ->  tại KHO_A
      07 PHẦN 1                    ->  CẢ BA site (thủ tục điều chuyển)
      10_PhanQuyen_Trigger.sql     ->  CẢ BA site

   Mất khoảng 15 phút. Chạy hết rồi mới demo được.
   ============================================================================ */

USE master;
GO

SET NOCOUNT ON;
GO

PRINT N'';
PRINT N'=== TRẠNG THÁI NHÂN BẢN TRƯỚC KHI DỌN ===';
GO

SELECT name AS CSDL,
       is_published    AS DangLamPublisher,
       is_subscribed   AS DangLamSubscriber
FROM   sys.databases
WHERE  name IN ('KhoA', 'KhoB', 'KhoC');
GO


/* ----------------------------------------------------------------------------
   BƯỚC 1. Xoá Subscription rồi mới xoá Publication

   Thứ tự này bắt buộc. Làm ngược lại sẽ nhận lỗi 14005 và cấu hình cũ vẫn
   còn nguyên, tưởng đã xoá mà thật ra chưa.
   ---------------------------------------------------------------------------- */
USE KhoA;
GO

IF EXISTS (SELECT 1 FROM syspublications WHERE name = N'PUB_DanhMuc')
BEGIN
    DECLARE @May SYSNAME = CAST(SERVERPROPERTY('MachineName') AS SYSNAME);

    BEGIN TRY
        EXEC sp_dropsubscription @publication = N'PUB_DanhMuc', @article = N'all',
             @subscriber = N'all', @destination_db = N'all';
        PRINT N'   Đã xoá toàn bộ Subscription';
    END TRY BEGIN CATCH
        PRINT N'   (Không có Subscription nào để xoá)';
    END CATCH

    BEGIN TRY
        EXEC sp_droppublication @publication = N'PUB_DanhMuc';
        PRINT N'   Đã xoá Publication PUB_DanhMuc';
    END TRY BEGIN CATCH
        PRINT N'   Lỗi khi xoá Publication: ' + ERROR_MESSAGE();
    END CATCH
END
ELSE
    PRINT N'   Không tìm thấy Publication PUB_DanhMuc - bỏ qua';
GO


/* ----------------------------------------------------------------------------
   BƯỚC 2. Tắt cờ "database này có nhân bản"

   Đây mới là thứ chặn lệnh DROP DATABASE. Xoá Publication thôi chưa đủ.
   ---------------------------------------------------------------------------- */
USE master;
GO

BEGIN TRY
    EXEC sp_replicationdboption @dbname = N'KhoA', @optname = N'publish', @value = N'false';
    PRINT N'   Đã tắt cờ publish cho KhoA';
END TRY BEGIN CATCH
    PRINT N'   KhoA vốn đã không bật publish - bỏ qua';
END CATCH
GO

BEGIN TRY
    EXEC sp_removedbreplication @dbname = N'KhoB';
    PRINT N'   Đã gỡ dấu vết nhân bản khỏi KhoB';
END TRY BEGIN CATCH END CATCH
GO

BEGIN TRY
    EXEC sp_removedbreplication @dbname = N'KhoC';
    PRINT N'   Đã gỡ dấu vết nhân bản khỏi KhoC';
END TRY BEGIN CATCH END CATCH
GO


/* ----------------------------------------------------------------------------
   BƯỚC 3. Kiểm chứng

   Cả ba cột phải về 0 thì lệnh DROP DATABASE ở script 01 mới chạy được.
   ---------------------------------------------------------------------------- */
PRINT N'';
PRINT N'=== TRẠNG THÁI SAU KHI DỌN (cả hai cột phải là 0) ===';
GO

SELECT name AS CSDL,
       is_published    AS DangLamPublisher,
       is_subscribed   AS DangLamSubscriber
FROM   sys.databases
WHERE  name IN ('KhoA', 'KhoB', 'KhoC');
GO

PRINT N'';
PRINT N'>>> Xong. Giờ chạy 01 tại KHO_A, 02 tại KHO_B, 03 tại KHO_C. <<<';
PRINT N'';
GO


/* ============================================================================
   PHỤ LỤC - GỠ LUÔN DISTRIBUTOR

   Chỉ chạy khối dưới đây khi muốn xoá sạch đến mức KHÔNG còn cấu hình nhân bản
   nào trên máy chủ, ví dụ khi cần chụp lại ảnh Configure Distribution Wizard
   cho mục 3.6 của báo cáo.

   Bình thường KHÔNG cần chạy - script 06 dùng lại Distributor sẵn có.
   Muốn chạy thì bôi đen từ đây xuống rồi bấm F5.
   ----------------------------------------------------------------------------

USE master;
GO

BEGIN TRY
    EXEC sp_dropdistpublisher @publisher = @@SERVERNAME, @no_checks = 1;
END TRY BEGIN CATCH PRINT ERROR_MESSAGE(); END CATCH
GO

BEGIN TRY
    EXEC sp_dropdistributiondb @database = N'distribution';
END TRY BEGIN CATCH PRINT ERROR_MESSAGE(); END CATCH
GO

BEGIN TRY
    EXEC sp_dropdistributor @no_checks = 1, @ignore_distributor = 1;
    PRINT N'Đã gỡ Distributor';
END TRY BEGIN CATCH PRINT ERROR_MESSAGE(); END CATCH
GO

   ============================================================================ */
